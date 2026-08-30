import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/service_module.dart';
import '../../../platform/activity/models/activity_item.dart';
import '../../../platform/activity/presentation/activity_controller.dart';
import '../../../platform/session/session_reset_registry.dart';
import '../../shared/data/cart_storage.dart';
import '../../shared/presentation/confirm_order_flow.dart';
import '../../shared/presentation/loadable_state_mixin.dart';
import '../data/pharmacy_repository.dart';
import '../models/pharmacy_cart_item.dart';
import '../models/pharmacy_checkout.dart';
import '../models/pharmacy_product.dart';

enum PharmacyCartAddResult {
  added,
  quantityIncreased,
  notOverTheCounter,
  unavailable,
  maximumStockReached,
}

class PharmacyController extends ChangeNotifier with LoadableState {
  PharmacyController({
    required PharmacyRepository repository,
    required ActivityController activityController,
    required CartStorage<PharmacyCartItem> storage,
    PharmacyOrderRepository? orderRepository,
    DateTime Function()? now,
  }) : _repository = repository,
       _activityController = activityController,
       _storage = storage,
       _orderRepository = orderRepository,
       _now = now ?? DateTime.now;

  static final PharmacyController instance = () {
    final client = Supabase.instance.client;
    final controller = PharmacyController(
      repository: SupabasePharmacyCatalogRepository(client: client),
      orderRepository: SupabasePharmacyOrderRepository(client: client),
      activityController: ActivityController.instance,
      storage: SharedPreferencesCartStorage<PharmacyCartItem>(
        keyPrefix: 'zivo.cart.v1.pharmacy',
        toJson: (item) => item.toJson(),
        fromJson: PharmacyCartItem.fromJson,
      ),
    );
    SessionResetRegistry.instance.register(
      (ownerId) => unawaited(controller.loadForOwner(ownerId)),
    );
    return controller;
  }();

  static const double deliveryFee = 2.50;

  /// How long a successful catalog load is considered fresh before
  /// [loadProducts] will silently refetch it again. A manual pull-to-refresh
  /// (via [loadProducts]'s `forceRefresh`) always bypasses this.
  static const Duration catalogStaleAfter = Duration(minutes: 5);

  final PharmacyRepository _repository;
  final ActivityController _activityController;
  final CartStorage<PharmacyCartItem> _storage;
  final PharmacyOrderRepository? _orderRepository;
  final DateTime Function() _now;
  final List<PharmacyProduct> _products = [];
  final List<PharmacyCartItem> _cartItems = [];

  static const String _guestCartOwner = 'guest';

  DateTime? _lastLoadedAt;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  Future<void> _pendingCartWrite = Future<void>.value();
  String? _cartOwnerId;
  int _cartLoadGeneration = 0;
  bool _isCartLoading = false;

  UnmodifiableListView<PharmacyProduct> get products =>
      UnmodifiableListView(_products);
  UnmodifiableListView<PharmacyCartItem> get cartItems =>
      UnmodifiableListView(_cartItems);

  /// Whether the loaded catalog is old enough that [loadProducts] should
  /// treat it as needing a refetch: never loaded, or last loaded at least
  /// [catalogStaleAfter] ago. Stock/price changes made server-side (e.g. an
  /// item selling out) only reach the client on the next refetch, so this
  /// keeps a session that stays open a long time from trusting an
  /// indefinitely old snapshot.
  bool get isStale {
    final lastLoadedAt = _lastLoadedAt;
    return lastLoadedAt == null ||
        _now().difference(lastLoadedAt) >= catalogStaleAfter;
  }

  bool get isLoadingMore => _isLoadingMore;

  /// Whether another page of products may exist. Starts `true` and flips
  /// to `false` once a fetched page comes back shorter than the requested
  /// page size (see [loadMore]).
  bool get hasMore => _hasMore;
  bool get isCartEmpty => _cartItems.isEmpty;
  bool get isCartNotEmpty => _cartItems.isNotEmpty;
  int get itemCount =>
      _cartItems.fold(0, (count, item) => count + item.quantity);
  double get subtotal =>
      _cartItems.fold(0, (total, item) => total + item.total);
  double get total => subtotal + (isCartEmpty ? 0 : deliveryFee);
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

  /// Loads the persisted pharmacy cart for [ownerId] (or the guest cart
  /// when `null`), replacing whatever cart is currently in memory. Mirrors
  /// `CartController.loadForOwner`: a monotonically increasing generation
  /// guards against a stale read finishing after a later account switch.
  Future<void> loadForOwner(String? ownerId) async {
    final generation = ++_cartLoadGeneration;
    _cartOwnerId = ownerId;
    _cartItems.clear();
    _isCartLoading = true;
    notifyListeners();

    List<PharmacyCartItem> loadedItems;
    try {
      loadedItems = await _storage.read(_cartStorageOwner);
    } on Object {
      loadedItems = const [];
    }
    if (generation != _cartLoadGeneration) {
      return;
    }

    _cartItems
      ..clear()
      ..addAll(loadedItems);
    _isCartLoading = false;
    notifyListeners();
  }

  /// Loads the OTC catalog.
  ///
  /// By default this is a no-op once a catalog is already loaded and still
  /// fresh (see [isStale]), so cheap repeat calls (e.g. from `initState`)
  /// don't refetch pointlessly. Pass [forceRefresh] to always refetch —
  /// this is what a pull-to-refresh gesture should use, since it represents
  /// an explicit user request for the latest stock/prices regardless of
  /// staleness.
  Future<void> loadProducts({bool forceRefresh = false}) async {
    if (isLoading) {
      return;
    }
    if (!forceRefresh && _products.isNotEmpty && !isStale) {
      return;
    }

    await runLoad(
      fetch: () async {
        final products = await _repository.fetchProducts(
          limit: pharmacyProductsPageSize,
        );
        _products
          ..clear()
          ..addAll(products.where((product) => product.isOverTheCounter));
        _hasMore = products.length >= pharmacyProductsPageSize;
        _lastLoadedAt = _now();
      },
      onError: (error, stackTrace) =>
          'The pharmacy catalog could not be loaded.',
    );
  }

  /// Fetches and appends the next page of products. No-ops while a load is
  /// already in flight or once [hasMore] is `false`.
  Future<void> loadMore() async {
    if (isLoading || _isLoadingMore || !_hasMore) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = await _repository.fetchProducts(
        limit: pharmacyProductsPageSize,
        offset: _products.length,
      );
      _products.addAll(nextPage.where((product) => product.isOverTheCounter));
      _hasMore = nextPage.length >= pharmacyProductsPageSize;
    } on Object {
      // Leave `_hasMore` as-is so the trailing "load more" control stays
      // visible and a subsequent scroll/tap can retry.
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  PharmacyCartAddResult addProduct(PharmacyProduct product) {
    if (!product.isOverTheCounter) {
      return PharmacyCartAddResult.notOverTheCounter;
    }
    if (!product.isAvailable) {
      return PharmacyCartAddResult.unavailable;
    }

    final index = _indexOf(product.id);
    if (index == -1) {
      _cartItems.add(PharmacyCartItem(product: product, quantity: 1));
      notifyListeners();
      unawaited(_persistCart());
      return PharmacyCartAddResult.added;
    }

    final item = _cartItems[index];
    if (item.quantity >= product.stockQuantity) {
      return PharmacyCartAddResult.maximumStockReached;
    }

    _cartItems[index] = item.copyWith(quantity: item.quantity + 1);
    notifyListeners();
    unawaited(_persistCart());
    return PharmacyCartAddResult.quantityIncreased;
  }

  void increment(String productId) {
    final index = _indexOf(productId);
    if (index == -1) {
      return;
    }

    final item = _cartItems[index];
    if (item.quantity >= item.product.stockQuantity) {
      return;
    }

    _cartItems[index] = item.copyWith(quantity: item.quantity + 1);
    notifyListeners();
    unawaited(_persistCart());
  }

  void decrement(String productId) {
    final index = _indexOf(productId);
    if (index == -1) {
      return;
    }

    final item = _cartItems[index];
    if (item.quantity <= 1) {
      removeProduct(productId);
      return;
    }

    _cartItems[index] = item.copyWith(quantity: item.quantity - 1);
    notifyListeners();
    unawaited(_persistCart());
  }

  void removeProduct(String productId) {
    final previousLength = _cartItems.length;
    _cartItems.removeWhere((item) => item.product.id == productId);
    if (_cartItems.length != previousLength) {
      notifyListeners();
      unawaited(_persistCart());
    }
  }

  void clearCart() {
    if (_cartItems.isEmpty) {
      return;
    }
    _cartItems.clear();
    notifyListeners();
    unawaited(_persistCart());
  }

  /// Resets ephemeral MVP state on an account switch. Kept for API
  /// compatibility; account switching itself is driven by [loadForOwner],
  /// which reloads (rather than simply clearing) the incoming owner's
  /// persisted cart.
  void resetSessionState() => clearCart();

  PharmacyCheckoutValidation validateCheckout(PharmacyCheckoutDetails details) {
    final errors = <String, String>{};

    if (_cartItems.isEmpty) {
      errors['cart'] = 'Add at least one OTC product before checkout.';
    }
    if (details.customerName.trim().length < 2) {
      errors['customerName'] = 'Enter the customer name.';
    }
    if (details.phoneNumber.trim().length < 7) {
      errors['phoneNumber'] = 'Enter a valid phone number.';
    }
    if (details.city.trim().isEmpty) {
      errors['city'] = 'Enter a city in Somalia.';
    }
    if (details.district.trim().isEmpty) {
      errors['district'] = 'Enter a district.';
    }
    if (details.addressLine.trim().length < 5) {
      errors['addressLine'] = 'Enter a complete delivery address.';
    }
    if (_cartItems.any(
      (item) =>
          !item.product.isOverTheCounter ||
          !item.product.isAvailable ||
          item.quantity > item.product.stockQuantity,
    )) {
      errors['stock'] =
          'One or more products are not eligible for this OTC order.';
    }

    return PharmacyCheckoutValidation(Map.unmodifiable(errors));
  }

  Future<PharmacyCheckoutResult> placeDemoOrder(
    PharmacyCheckoutDetails details,
  ) {
    final validation = validateCheckout(details);
    final confirmedAt = _now();
    // Snapshot cart-derived values before the shared flow clears the cart.
    final confirmedTotal = total;
    final confirmedItemCount = itemCount;
    final confirmedItems = _cartItems
        .map(
          (item) => PharmacyOrderLineInput(
            productId: item.product.id,
            quantity: item.quantity,
          ),
        )
        .toList(growable: false);

    return confirmDemoOrder<PharmacyCheckoutResult, PharmacyCheckoutValidation>(
      validation: validation,
      isValid: (validation) => validation.isValid,
      onInvalid: (validation) => PharmacyCheckoutResult.invalid(validation),
      placeOrder: () =>
          _orderRepository?.placeOrder(
            PharmacyOrderRequest(details: details, items: confirmedItems),
          ) ??
          Future.value(null),
      fallbackOrderId: () => 'pharmacy-${confirmedAt.microsecondsSinceEpoch}',
      onSaveFailed: () => PharmacyCheckoutResult.invalid(
        const PharmacyCheckoutValidation({
          'order': 'The pharmacy order could not be saved. Please try again.',
        }),
      ),
      recordActivity: (orderId) {
        _activityController.record(
          ActivityItem(
            id: orderId,
            serviceId: ServiceId.pharmacy,
            title: 'Pharmacy order',
            subtitle:
                '$confirmedItemCount OTC '
                '${confirmedItemCount == 1 ? 'item' : 'items'}',
            status: 'Demo confirmed',
            occurredAt: confirmedAt,
            amount: confirmedTotal,
            detailsRoute: '/pharmacy',
          ),
        );
      },
      clearCart: clearCart,
      onConfirmed: (orderId) => PharmacyCheckoutResult.success(
        orderId: orderId,
        message:
            'Order confirmed. No payment was processed and no order '
            'was sent to a pharmacy.',
      ),
    );
  }

  int _indexOf(String productId) {
    return _cartItems.indexWhere((item) => item.product.id == productId);
  }

  Future<void> _persistCart() {
    final owner = _cartStorageOwner;
    final snapshot = List<PharmacyCartItem>.from(_cartItems);
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
