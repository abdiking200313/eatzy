import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/service_module.dart';
import '../../../platform/activity/models/activity_item.dart';
import '../../../platform/activity/presentation/activity_controller.dart';
import '../../../platform/session/session_reset_registry.dart';
import '../../shared/data/cart_storage.dart';
import '../../shared/data/idempotency_key.dart';
import '../../shared/data/rpc_helpers.dart';
import '../../shared/presentation/confirm_order_flow.dart';
import '../../shared/presentation/loadable_state_mixin.dart';
import '../data/grocery_repository.dart';
import '../models/grocery_models.dart';

enum GroceryAddResult {
  added,
  quantityIncreased,
  unavailable,
  storeConflict,
  stockLimitReached,
}

class GroceryController extends ChangeNotifier with LoadableState {
  GroceryController({
    required GroceryRepository repository,
    required CartStorage<GroceryCartLine> storage,
    GroceryCatalogRepository? catalogRepository,
    GroceryOrderRepository? orderRepository,
    ActivityController? activityController,
    DateTime Function()? now,
  }) : _repository = repository,
       _storage = storage,
       _catalogRepository =
           catalogRepository ??
           (repository is GroceryCatalogRepository
               ? repository as GroceryCatalogRepository
               : null),
       _orderRepository = orderRepository,
       _activityController = activityController ?? ActivityController.instance,
       _now = now ?? DateTime.now;

  // Deliberately does not call load() here: constructing this singleton
  // must not issue catalog queries for users who never open the grocery
  // vertical. Callers (GroceryScreen and friends) trigger load() on demand.
  static final GroceryController instance = () {
    final client = Supabase.instance.client;
    final catalog = SupabaseGroceryCatalogRepository(client: client);
    final controller = GroceryController(
      repository: catalog,
      catalogRepository: catalog,
      orderRepository: SupabaseGroceryOrderRepository(client: client),
      storage: SharedPreferencesCartStorage<GroceryCartLine>(
        keyPrefix: 'zivo.cart.v1.grocery',
        toJson: (line) => line.toJson(),
        fromJson: GroceryCartLine.fromJson,
      ),
    );
    SessionResetRegistry.instance.register((ownerId) {
      controller.resetSessionState();
      unawaited(controller.loadForOwner(ownerId));
    });
    return controller;
  }();

  /// In integer cents — see issue #8.
  static const int standardDeliveryFee = 250;

  /// How long a successful store/catalog load is considered fresh before
  /// [load] will silently refetch it again. A manual pull-to-refresh (via
  /// [load]'s `forceRefresh`) always bypasses this.
  static const Duration catalogStaleAfter = Duration(minutes: 5);

  static const List<GroceryDeliverySlot> deliverySlots = [
    GroceryDeliverySlot(
      id: 'today-afternoon',
      label: 'Today',
      detail: '2:00 PM – 4:00 PM',
    ),
    GroceryDeliverySlot(
      id: 'today-evening',
      label: 'Today',
      detail: '6:00 PM – 8:00 PM',
    ),
    GroceryDeliverySlot(
      id: 'tomorrow-morning',
      label: 'Tomorrow',
      detail: '9:00 AM – 11:00 AM',
    ),
  ];

  final GroceryRepository _repository;
  final CartStorage<GroceryCartLine> _storage;
  final GroceryCatalogRepository? _catalogRepository;
  final GroceryOrderRepository? _orderRepository;
  final ActivityController _activityController;
  final DateTime Function() _now;
  final List<GroceryStore> _stores = [];
  final List<GroceryDeliverySlot> _deliverySlots = [];
  final Map<String, GroceryCartLine> _cart = {};

  /// Store IDs individually fetched via [loadStore] (as opposed to via the
  /// every-store [load]). Consulted by [hasLoadedStore] so a screen scoped
  /// to one store doesn't need the full multi-store catalog loaded first.
  final Set<String> _loadedStoreIds = {};

  static const String _guestCartOwner = 'guest';

  bool _hasLoaded = false;
  DateTime? _lastLoadedAt;
  bool _slotsLoading = false;
  String? _slotLoadError;
  GroceryOrderConfirmation? _lastConfirmation;
  bool _isSubmitting = false;

  Future<void> _pendingCartWrite = Future<void>.value();
  String? _cartOwnerId;
  int _cartLoadGeneration = 0;
  bool _isCartLoading = false;

  UnmodifiableListView<GroceryStore> get stores =>
      UnmodifiableListView(_stores);
  UnmodifiableListView<GroceryCartLine> get cart =>
      UnmodifiableListView(_cart.values.toList(growable: false));
  bool get hasLoaded => _hasLoaded;

  /// Whether [storeId] can be found in [stores]: either the full catalog
  /// has been loaded at least once (via [load]), or that specific store was
  /// individually loaded via [loadStore]. `GroceryStoreScreen` gates on this
  /// instead of [hasLoaded] so a direct/deep link to one store doesn't wait
  /// on (or force) an every-store load first.
  bool hasLoadedStore(String storeId) =>
      _hasLoaded || _loadedStoreIds.contains(storeId);

  /// Whether the loaded stores/catalog are old enough that [load] should
  /// treat them as needing a refetch: never loaded, or last loaded at least
  /// [catalogStaleAfter] ago. Stock/price changes made server-side only
  /// reach the client on the next refetch, so this keeps a session that
  /// stays open a long time from trusting an indefinitely old snapshot.
  bool get isStale {
    final lastLoadedAt = _lastLoadedAt;
    return lastLoadedAt == null ||
        _now().difference(lastLoadedAt) >= catalogStaleAfter;
  }

  bool get slotsLoading => _slotsLoading;
  String? get slotLoadError => _slotLoadError;
  UnmodifiableListView<GroceryDeliverySlot> get availableDeliverySlots =>
      UnmodifiableListView(
        _catalogRepository == null ? deliverySlots : _deliverySlots,
      );
  bool get isEmpty => _cart.isEmpty;
  bool get isNotEmpty => _cart.isNotEmpty;
  int get itemCount => _cart.length;
  GroceryOrderConfirmation? get lastConfirmation => _lastConfirmation;

  /// Whether a [confirmOrder] call is currently in flight. The checkout
  /// screen disables its submit button while this is true — see issue #59 —
  /// and [confirmOrder] itself also refuses to start a second submission
  /// while this is true, as a belt-and-braces guard against a double-tap or
  /// a second programmatic call racing the first one.
  bool get isSubmitting => _isSubmitting;
  String? get cartOwnerId => _cartOwnerId;
  bool get isCartLoading => _isCartLoading;
  String get _cartStorageOwner => _cartOwnerId ?? _guestCartOwner;

  /// Resolves once every cart write queued so far has been persisted. Cart
  /// mutations persist fire-and-forget so callers don't need to await them;
  /// tests that need to observe the persisted result deterministically
  /// (e.g. before loading a second controller from the same storage) should
  /// await this first.
  @visibleForTesting
  Future<void> get pendingCartWrite => _pendingCartWrite;
  String? get storeId =>
      _cart.isEmpty ? null : _cart.values.first.product.storeId;

  String? get storeName {
    final selectedStoreId = storeId;
    if (selectedStoreId == null) {
      return null;
    }
    for (final store in _stores) {
      if (store.id == selectedStoreId) {
        return store.name;
      }
    }
    return null;
  }

  int get subtotal => _cart.values.fold(0, (total, line) => total + line.total);
  int get deliveryFee => _cart.isEmpty ? 0 : standardDeliveryFee;
  int get total => subtotal + deliveryFee;

  /// Loads the persisted grocery cart for [ownerId] (or the guest cart when
  /// `null`), replacing whatever cart is currently in memory. Mirrors
  /// `CartController.loadForOwner`: a monotonically increasing generation
  /// guards against a stale read finishing after a later account switch.
  Future<void> loadForOwner(String? ownerId) async {
    final generation = ++_cartLoadGeneration;
    _cartOwnerId = ownerId;
    _cart.clear();
    _isCartLoading = true;
    notifyListeners();

    List<GroceryCartLine> loadedLines;
    try {
      loadedLines = await _storage.read(_cartStorageOwner);
    } on Object {
      loadedLines = const [];
    }
    if (generation != _cartLoadGeneration) {
      return;
    }

    _cart
      ..clear()
      ..addEntries(loadedLines.map((line) => MapEntry(line.product.id, line)));
    _isCartLoading = false;
    notifyListeners();
  }

  /// Loads the store/product catalog.
  ///
  /// By default this is a no-op once the catalog is already loaded and
  /// still fresh (see [isStale]), so cheap repeat calls (e.g. from
  /// `initState`) don't refetch pointlessly. Pass [forceRefresh] to always
  /// refetch — this is what a pull-to-refresh gesture should use, since it
  /// represents an explicit user request for the latest stock/prices
  /// regardless of staleness.
  Future<void> load({bool forceRefresh = false}) async {
    if (isLoading) {
      return;
    }
    if (!forceRefresh && _hasLoaded && !isStale) {
      return;
    }
    await runLoad(
      fetch: () async {
        final stores = await _repository.fetchStores();
        _stores
          ..clear()
          ..addAll(stores);
        _hasLoaded = true;
        _lastLoadedAt = _now();
      },
      onError: (error, stackTrace) =>
          'Groceries could not be loaded. Please try again.',
    );
  }

  /// Loads a single store (and just its own products), scoped by [storeId]
  /// — the store-detail counterpart of [load], which fetches every active
  /// store at once for the store-*list* screen. `GroceryStoreScreen` should
  /// call this instead of [load] so opening one store (including a cold
  /// start/deep link before [stores] holds anything yet) never has to pull
  /// every other store's catalog just to render one.
  ///
  /// Falls back to [load] when the injected repository doesn't implement
  /// [GroceryCatalogRepository] (e.g. [SeededGroceryRepository] in tests) —
  /// the full catalog it fetches already contains every store, this one
  /// included.
  Future<void> loadStore(String storeId, {bool forceRefresh = false}) async {
    final catalogRepository = _catalogRepository;
    if (catalogRepository == null) {
      return load(forceRefresh: forceRefresh);
    }
    if (isLoading) {
      return;
    }
    if (!forceRefresh && hasLoadedStore(storeId) && !isStale) {
      return;
    }
    await runLoad(
      fetch: () async {
        final store = await catalogRepository.fetchStore(storeId);
        if (store != null) {
          final index = _stores.indexWhere(
            (existing) => existing.id == store.id,
          );
          if (index == -1) {
            _stores.add(store);
          } else {
            _stores[index] = store;
          }
          _loadedStoreIds.add(storeId);
        }
        _lastLoadedAt = _now();
      },
      onError: (error, stackTrace) =>
          'This store could not be loaded. Please try again.',
    );
  }

  Future<void> loadDeliverySlots() async {
    final selectedStoreId = storeId;
    final catalogRepository = _catalogRepository;
    if (selectedStoreId == null || catalogRepository == null || _slotsLoading) {
      return;
    }

    _slotsLoading = true;
    _slotLoadError = null;
    notifyListeners();
    try {
      final slots = await catalogRepository.fetchDeliverySlots(selectedStoreId);
      _deliverySlots
        ..clear()
        ..addAll(slots);
    } on Object {
      _slotLoadError = 'Delivery slots could not be loaded.';
    } finally {
      _slotsLoading = false;
      notifyListeners();
    }
  }

  GroceryAddResult addProduct(
    GroceryProduct product, {
    bool replaceStoreCart = false,
  }) {
    if (!product.isAvailable) {
      return GroceryAddResult.unavailable;
    }

    if (_cart.isNotEmpty && storeId != product.storeId && !replaceStoreCart) {
      return GroceryAddResult.storeConflict;
    }

    if (replaceStoreCart && storeId != product.storeId) {
      _cart.clear();
    }

    final existing = _cart[product.id];
    final nextQuantity = (existing?.quantity ?? 0) + product.quantityStep;
    if (nextQuantity > product.availableQuantity) {
      return GroceryAddResult.stockLimitReached;
    }

    _cart[product.id] = GroceryCartLine(
      product: product,
      quantity: _normalizeQuantity(nextQuantity),
    );
    _lastConfirmation = null;
    notifyListeners();
    unawaited(_persistCart());
    return existing == null
        ? GroceryAddResult.added
        : GroceryAddResult.quantityIncreased;
  }

  bool setQuantity(String productId, double quantity) {
    final existing = _cart[productId];
    if (existing == null) {
      return false;
    }

    if (quantity <= 0) {
      _cart.remove(productId);
      notifyListeners();
      unawaited(_persistCart());
      return true;
    }

    final product = existing.product;
    final steps = quantity / product.quantityStep;
    final isValidStep = (steps - steps.round()).abs() < 0.0001;
    if (!isValidStep || quantity > product.availableQuantity) {
      return false;
    }

    _cart[productId] = existing.copyWith(
      quantity: _normalizeQuantity(quantity),
    );
    notifyListeners();
    unawaited(_persistCart());
    return true;
  }

  bool increment(String productId) {
    final existing = _cart[productId];
    if (existing == null) {
      return false;
    }
    return setQuantity(
      productId,
      existing.quantity + existing.product.quantityStep,
    );
  }

  bool decrement(String productId) {
    final existing = _cart[productId];
    if (existing == null) {
      return false;
    }
    return setQuantity(
      productId,
      existing.quantity - existing.product.quantityStep,
    );
  }

  void remove(String productId) {
    if (_cart.remove(productId) != null) {
      notifyListeners();
      unawaited(_persistCart());
    }
  }

  List<String> validateCheckout({
    required GroceryDeliveryAddress address,
    required GroceryDeliverySlot? slot,
    required GrocerySubstitutionPreference? substitutionPreference,
  }) {
    final errors = <String>[];
    if (_cart.isEmpty) {
      errors.add('Add at least one grocery item.');
    }
    if (address.recipientName.trim().isEmpty) {
      errors.add('Enter the recipient name.');
    }
    if (address.phone.trim().length < 7) {
      errors.add('Enter a valid phone number.');
    }
    if (address.street.trim().isEmpty) {
      errors.add('Enter a street or landmark.');
    }
    if (address.district.trim().isEmpty) {
      errors.add('Enter a district.');
    }
    if (address.city.trim().isEmpty) {
      errors.add('Enter a city.');
    }
    if (address.country.trim().toLowerCase() != 'somalia') {
      errors.add('The MVP currently delivers within Somalia only.');
    }
    if (slot == null) {
      errors.add('Choose a delivery slot.');
    }
    if (substitutionPreference == null) {
      errors.add('Choose a substitution preference.');
    }
    return errors;
  }

  /// Validates the cart/address/slot/preference and, once valid, places the
  /// order through the shared [confirmDemoOrder] flow, records activity,
  /// and clears the cart.
  ///
  /// A no-op — without touching submission state — while a previous call is
  /// still in flight (see [isSubmitting]): this is a belt-and-braces guard
  /// against a double-tap or a second programmatic call racing the first
  /// one, on top of the checkout screen already disabling its submit button
  /// while [isSubmitting] is true (issue #59).
  ///
  /// [idempotencyKey] identifies this checkout *attempt* and is forwarded
  /// to `place_grocery_order` so a retried submission (the same key)
  /// returns the existing order instead of creating a duplicate and
  /// decrementing stock again. Callers should generate one per attempt
  /// (e.g. once per checkout screen visit) and keep passing the same value
  /// across retries of that attempt; when omitted, a fresh key is generated
  /// for this call only, which gives no protection against a retry that
  /// calls this method again.
  Future<GroceryCheckoutResult> confirmOrder({
    required GroceryDeliveryAddress address,
    required GroceryDeliverySlot? slot,
    required GrocerySubstitutionPreference? substitutionPreference,
    String? idempotencyKey,
    DateTime? now,
  }) {
    if (_isSubmitting) {
      return Future.value(GroceryCheckoutResult.invalid(const []));
    }

    final errors = validateCheckout(
      address: address,
      slot: slot,
      substitutionPreference: substitutionPreference,
    );
    final createdAt = now ?? DateTime.now();
    // Snapshot cart-derived values before the shared flow clears the cart.
    // These are only used for the no-repository (demo) fallback below —
    // once a real repository is configured, the RPC's returned totals
    // (issue #60) are used instead.
    final confirmedStoreId = storeId;
    final confirmedStoreName = storeName;
    final confirmedSubtotal = subtotal;
    final confirmedDeliveryFee = deliveryFee;
    final confirmedAmount = total;
    final confirmedItems = _cart.values
        .map(
          (line) => GroceryOrderLineInput(
            productId: line.product.id,
            quantity: line.quantity,
          ),
        )
        .toList(growable: false);
    final resolvedIdempotencyKey = idempotencyKey ?? generateIdempotencyKey();
    GroceryOrderConfirmation? confirmation;

    if (errors.isNotEmpty) {
      return Future.value(GroceryCheckoutResult.invalid(errors));
    }

    _isSubmitting = true;
    notifyListeners();

    return confirmDemoOrder<GroceryCheckoutResult, List<String>, PlacedOrder>(
      validation: errors,
      isValid: (validation) => validation.isEmpty,
      onInvalid: (validation) => GroceryCheckoutResult.invalid(validation),
      placeOrder: () =>
          _orderRepository?.placeOrder(
            GroceryOrderRequest(
              storeId: confirmedStoreId!,
              deliverySlotId: slot!.id,
              address: address,
              substitutionPreference: substitutionPreference!,
              items: confirmedItems,
              idempotencyKey: resolvedIdempotencyKey,
            ),
          ) ??
          Future.value(null),
      fallbackOrder: () => PlacedOrder(
        orderId: 'grocery-${createdAt.microsecondsSinceEpoch}',
        subtotal: confirmedSubtotal,
        deliveryFee: confirmedDeliveryFee,
        tax: 0,
        total: confirmedAmount,
      ),
      onSaveFailed: () => GroceryCheckoutResult.invalid([
        'The grocery order could not be saved. Please try again.',
      ]),
      // `order.total` is the RPC's authoritative, server-computed total
      // (issue #60) — not the client-computed `confirmedAmount`, which can
      // be stale if a product price changed between the cart being built
      // and this checkout being confirmed.
      recordActivity: (order) {
        confirmation = GroceryOrderConfirmation(
          orderId: order.orderId,
          createdAt: createdAt,
          amount: order.total,
          slot: slot!,
          address: address,
          substitutionPreference: substitutionPreference!,
        );
        _activityController.record(
          ActivityItem(
            id: order.orderId,
            serviceId: ServiceId.grocery,
            title: confirmedStoreName ?? 'Grocery order',
            subtitle: '${slot.label}, ${slot.detail}',
            status: 'Demo confirmed',
            occurredAt: createdAt,
            amount: order.total,
            detailsRoute: '/grocery',
            paymentMethod: 'cash_on_delivery',
            paymentStatus: 'pending_collection',
          ),
        );
      },
      clearCart: () {
        _cart.clear();
        return _persistCart();
      },
      onConfirmed: (order) {
        _lastConfirmation = confirmation;
        notifyListeners();
        return GroceryCheckoutResult.confirmed(confirmation!);
      },
    ).whenComplete(() {
      _isSubmitting = false;
      notifyListeners();
    });
  }

  @visibleForTesting
  void clear() {
    _cart.clear();
    resetSessionState();
  }

  /// Resets ephemeral, non-persisted MVP state on an account switch. The
  /// cart itself is handled separately by [loadForOwner], which reloads
  /// (rather than simply clearing) the incoming owner's persisted cart.
  void resetSessionState() {
    _deliverySlots.clear();
    _lastConfirmation = null;
    notifyListeners();
  }

  double _normalizeQuantity(double quantity) =>
      (quantity * 100).roundToDouble() / 100;

  Future<void> _persistCart() {
    final owner = _cartStorageOwner;
    final snapshot = _cart.values.toList(growable: false);
    return _queueCartWrite(() => _storage.write(owner, snapshot));
  }

  Future<void> _queueCartWrite(Future<void> Function() write) {
    final previousWrite = _pendingCartWrite;
    final operation = () async {
      try {
        await previousWrite;
      } on Object {
        // A later cart change should still get a chance to persist.
      }
      await write();
    }();
    _pendingCartWrite = operation;
    return operation;
  }
}
