import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../platform/activity/presentation/activity_controller.dart';
import '../../shared/data/cart_storage.dart';
import '../../shared/data/service_pricing_repository.dart';
import '../../shared/models/delivery_details.dart';
import '../../shared/models/service_pricing.dart';
import '../../shared/presentation/loadable_state_mixin.dart';
import '../data/grocery_repository.dart';
import '../models/grocery_models.dart';
import 'grocery_cart.dart';
import 'grocery_catalog.dart';
import 'grocery_checkout.dart';

export 'grocery_cart.dart' show GroceryAddResult;

class GroceryController extends ChangeNotifier with LoadableState {
  GroceryController({
    required GroceryRepository repository,
    required CartStorage<GroceryCartLine> storage,
    GroceryCatalogRepository? catalogRepository,
    GroceryOrderRepository? orderRepository,
    ActivityController? activityController,
    ServicePricingRepository? pricingRepository,
    DateTime Function()? now,
    this.storeType = GroceryStoreType.grocery,
  }) : _pricingRepository =
           pricingRepository ?? SupabaseServicePricingRepository(),
       _cart = GroceryCart(storage: storage),
       _catalog = GroceryCatalog(
         repository: repository,
         storeType: storeType,
         catalogRepository: catalogRepository,
         now: now,
         staleAfter: catalogStaleAfter,
       ),
       _checkout = GroceryCheckout(
         orderRepository: orderRepository,
         activityController: activityController ?? ActivityController.instance,
         storeType: storeType,
       );

  /// Which category this controller serves. Grocery, Fresh Meat and
  /// Electronics share this engine but each has its own controller, so each
  /// keeps its own cart and store list (owner decision, 2026-09-25).
  final GroceryStoreType storeType;

  /// The `service_pricing.service_id` this vertical's fee estimate is read
  /// from — see [ServicePricingRepository]. Fresh Meat and
  /// Electronics run on this same engine and share this same pricing row:
  /// `place_grocery_order` always reads `service_id = 'grocery'` regardless
  /// of [storeType], so this does not vary by [storeType] either.
  static const String serviceId = 'grocery';

  /// How long a successful store/catalog load is considered fresh before
  /// [load] will silently refetch it again. A manual pull-to-refresh (via
  /// [load]'s `forceRefresh`) always bypasses this.
  static const Duration catalogStaleAfter = Duration(minutes: 5);

  static const List<GroceryDeliverySlot> deliverySlots =
      defaultGroceryDeliverySlots;

  final ServicePricingRepository _pricingRepository;

  /// Cart contents, quantity-step rules and persistence — see [GroceryCart].
  final GroceryCart _cart;

  /// Store/product catalog loading and caching — see [GroceryCatalog].
  final GroceryCatalog _catalog;

  /// Checkout validation, order placement and submission state — see
  /// [GroceryCheckout].
  final GroceryCheckout _checkout;

  UnmodifiableListView<GroceryStore> get stores => _catalog.stores;
  UnmodifiableListView<GroceryCartLine> get cart => _cart.lines;
  bool get hasLoaded => _catalog.hasLoaded;

  /// Whether [storeId] can be found in [stores]: either the full catalog
  /// has been loaded at least once (via [load]), or that specific store was
  /// individually loaded via [loadStore]. `GroceryStoreScreen` gates on this
  /// instead of [hasLoaded] so a direct/deep link to one store doesn't wait
  /// on (or force) an every-store load first.
  bool hasLoadedStore(String storeId) => _catalog.hasLoadedStore(storeId);

  /// Whether the loaded stores/catalog are old enough that [load] should
  /// treat them as needing a refetch: never loaded, or last loaded at least
  /// [catalogStaleAfter] ago. Stock/price changes made server-side only
  /// reach the client on the next refetch, so this keeps a session that
  /// stays open a long time from trusting an indefinitely old snapshot.
  bool get isStale => _catalog.isStale;

  bool get slotsLoading => _catalog.slotsLoading;
  String? get slotLoadError => _catalog.slotLoadError;
  UnmodifiableListView<GroceryDeliverySlot> get availableDeliverySlots =>
      _catalog.availableDeliverySlots;
  bool get isEmpty => _cart.isEmpty;
  bool get isNotEmpty => _cart.isNotEmpty;
  int get itemCount => _cart.itemCount;
  GroceryOrderConfirmation? get lastConfirmation => _checkout.lastConfirmation;

  /// Whether a [confirmOrder] call is currently in flight. The checkout
  /// screen disables its submit button while this is true, and
  /// [confirmOrder] itself also refuses to start a second submission
  /// while this is true, as a belt-and-braces guard against a double-tap or
  /// a second programmatic call racing the first one.
  bool get isSubmitting => _checkout.isSubmitting;
  String? get cartOwnerId => _cart.ownerId;
  bool get isCartLoading => _cart.isLoading;

  /// Resolves once every cart write queued so far has been persisted. Cart
  /// mutations persist fire-and-forget so callers don't need to await them;
  /// tests that need to observe the persisted result deterministically
  /// (e.g. before loading a second controller from the same storage) should
  /// await this first.
  @visibleForTesting
  Future<void> get pendingCartWrite => _cart.pendingWrite;
  String? get storeId => _cart.storeId;

  String? get storeName {
    final selectedStoreId = storeId;
    if (selectedStoreId == null) {
      return null;
    }
    for (final store in _catalog.stores) {
      if (store.id == selectedStoreId) {
        return store.name;
      }
    }
    return null;
  }

  int get subtotal => _cart.subtotal;

  /// The last successfully loaded delivery-fee config for this vertical, or
  /// `null` if none has loaded yet — see [ServicePricingRepository.peek].
  ServicePricing? get pricing => _pricingRepository.peek(serviceId);

  /// `null` means pricing hasn't loaded yet: [total] is `null` too, and the
  /// UI should show "Calculated at checkout" instead of a fabricated number.
  /// An empty cart always reports `0` regardless, since there is nothing to
  /// price.
  int? get deliveryFee {
    if (_cart.isEmpty) return 0;
    return pricing?.deliveryFeeCents;
  }

  int? get total {
    final fee = deliveryFee;
    if (fee == null) return null;
    return subtotal + fee;
  }

  /// Loads the persisted grocery cart for [ownerId] (or the guest cart when
  /// `null`), replacing whatever cart is currently in memory. Mirrors
  /// `CartController.loadForOwner`: a monotonically increasing generation
  /// guards against a stale read finishing after a later account switch.
  Future<void> loadForOwner(String? ownerId) async {
    final completed = await _cart.loadForOwner(
      ownerId,
      onChanged: notifyListeners,
    );
    if (completed) {
      unawaited(_loadPricing());
    }
  }

  /// Warms (or refreshes) [pricing] in the background; never throws.
  Future<void> _loadPricing() async {
    final loaded = await _pricingRepository.load(serviceId);
    if (loaded != null) {
      notifyListeners();
    }
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
    if (!forceRefresh && _catalog.hasLoaded && !_catalog.isStale) {
      return;
    }
    await runLoad(
      fetch: _catalog.load,
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
    if (_catalog.catalogRepository == null) {
      return load(forceRefresh: forceRefresh);
    }
    if (isLoading) {
      return;
    }
    if (!forceRefresh && hasLoadedStore(storeId) && !_catalog.isStale) {
      return;
    }
    await runLoad(
      fetch: () => _catalog.loadStore(storeId),
      onError: (error, stackTrace) =>
          'This store could not be loaded. Please try again.',
    );
  }

  Future<void> loadDeliverySlots() async {
    await _catalog.loadDeliverySlots(storeId, onChanged: notifyListeners);
  }

  /// Adds [steps] quantity steps of [product] (one item, or 0.5 kg per
  /// step) -- all or nothing: if that would exceed the available stock,
  /// nothing is added and [GroceryAddResult.stockLimitReached] is returned.
  GroceryAddResult addProduct(
    GroceryProduct product, {
    bool replaceStoreCart = false,
    int steps = 1,
  }) {
    final result = _cart.addProduct(
      product,
      replaceStoreCart: replaceStoreCart,
      steps: steps,
    );
    if (result == GroceryAddResult.added ||
        result == GroceryAddResult.quantityIncreased) {
      _checkout.resetConfirmation();
      notifyListeners();
    }
    return result;
  }

  bool setQuantity(String productId, double quantity) {
    final changed = _cart.setQuantity(productId, quantity);
    if (changed) {
      notifyListeners();
    }
    return changed;
  }

  bool increment(String productId) {
    final changed = _cart.increment(productId);
    if (changed) {
      notifyListeners();
    }
    return changed;
  }

  bool decrement(String productId) {
    final changed = _cart.decrement(productId);
    if (changed) {
      notifyListeners();
    }
    return changed;
  }

  void remove(String productId) {
    if (_cart.remove(productId)) {
      notifyListeners();
    }
  }

  List<String> validateCheckout({
    required GroceryDeliverySlot? slot,
    required GrocerySubstitutionPreference? substitutionPreference,
  }) {
    return _checkout.validate(
      cartIsEmpty: _cart.isEmpty,
      slot: slot,
      substitutionPreference: substitutionPreference,
    );
  }

  /// Validates the cart/slot/preference and, once valid, places the order —
  /// see [GroceryCheckout.confirmOrder], which this delegates to after
  /// snapshotting the current cart/pricing state (so the snapshot is taken
  /// before [GroceryCheckout] clears the cart).
  ///
  /// A no-op — without touching submission state — while a previous call is
  /// still in flight (see [isSubmitting]): this is a belt-and-braces guard
  /// against a double-tap or a second programmatic call racing the first
  /// one, on top of the checkout screen already disabling its submit button
  /// while [isSubmitting] is true.
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
    DeliveryDetails delivery = const DeliveryDetails(),
    required GroceryDeliverySlot? slot,
    required GrocerySubstitutionPreference? substitutionPreference,
    String? idempotencyKey,
    DateTime? now,
  }) {
    final errors = validateCheckout(
      slot: slot,
      substitutionPreference: substitutionPreference,
    );
    // Snapshot cart-derived values before the shared flow clears the cart.
    // These are only used for the no-repository (demo) fallback -- once a
    // real repository is configured, the RPC's returned totals are used
    // instead.
    final confirmedItems = _cart.lines
        .map(
          (line) => GroceryOrderLineInput(
            productId: line.product.id,
            quantity: line.quantity,
          ),
        )
        .toList(growable: false);

    return _checkout.confirmOrder(
      validationErrors: errors,
      storeId: storeId,
      storeName: storeName,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      total: total,
      items: confirmedItems,
      delivery: delivery,
      slot: slot,
      substitutionPreference: substitutionPreference,
      clearCart: _cart.clearAndPersist,
      idempotencyKey: idempotencyKey,
      now: now,
      onChanged: notifyListeners,
    );
  }

  @visibleForTesting
  void clear() {
    _cart.clearInMemory();
    resetSessionState();
  }

  /// Resets ephemeral, non-persisted MVP state on an account switch. The
  /// cart itself is handled separately by [loadForOwner], which reloads
  /// (rather than simply clearing) the incoming owner's persisted cart.
  void resetSessionState() {
    _catalog.resetDeliverySlots();
    _checkout.resetConfirmation();
    notifyListeners();
  }
}
