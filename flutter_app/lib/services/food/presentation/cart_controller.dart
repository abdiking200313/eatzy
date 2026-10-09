import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../services/shared/data/cart_storage.dart';
import '../../../services/shared/data/service_pricing_repository.dart';
import '../../../services/shared/models/service_pricing.dart';
import '../models/cart_item.dart';

enum CartAddResult {
  added,
  quantityIncreased,
  replacedRestaurant,
  restaurantConflict,
  maximumReached,
}

class CartController extends ChangeNotifier {
  CartController({
    required CartStorage<CartItem> storage,
    ServicePricingRepository? pricingRepository,
  }) : _storage = storage,
       _pricingRepository =
           pricingRepository ?? SupabaseServicePricingRepository();

  /// Process-wide singleton, kept for every call site that hasn't migrated
  /// yet. New code should prefer `AppScope.of(context).cartController`
  /// (`lib/app/app_scope.dart`) instead of reaching for this
  /// directly -- it resolves to the exact same object in production, just
  /// through the app's composition root rather than a global.
  static final CartController instance = CartController(
    storage: SharedPreferencesCartStorage<CartItem>(
      keyPrefix: 'zivo.cart.v1',
      toJson: (item) => item.toJson(),
      fromJson: CartItem.fromJson,
    ),
  );

  static const int maximumQuantity = 99;

  /// The `service_pricing.service_id` this vertical's fee/tax estimate is
  /// read from — see [ServicePricingRepository].
  static const String serviceId = 'food';

  static const String _guestOwner = 'guest';

  final CartStorage<CartItem> _storage;
  final ServicePricingRepository _pricingRepository;
  final List<CartItem> _items = [];

  final CartWriteQueue _writeQueue = CartWriteQueue(label: 'CartController');
  String? _ownerId;
  int _loadGeneration = 0;
  bool _isLoading = false;

  List<CartItem> get items => List.unmodifiable(_items);
  String? get ownerId => _ownerId;
  bool get isLoading => _isLoading;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  String? get restaurantId => _items.isEmpty ? null : _items.first.restaurantId;
  String? get restaurantName =>
      _items.isEmpty ? null : _items.first.restaurantName;
  int get itemCount => _items.fold(0, (count, item) => count + item.quantity);
  int get subtotal => _items.fold(0, (total, item) => total + item.total);

  /// The last successfully loaded delivery-fee/tax-rate config for this
  /// vertical, or `null` if none has loaded yet — see
  /// [ServicePricingRepository.peek].
  ServicePricing? get pricing => _pricingRepository.peek(serviceId);

  /// `null` means pricing hasn't loaded yet: [tax], [deliveryFee], and
  /// [total] are all `null` in that case too, and the UI should show
  /// "Calculated at checkout" instead of a fabricated number. An empty cart
  /// always reports `0` regardless, since there is nothing to price.
  ///
  /// Rounded with `.round()` at the point it combines with other integer-cent
  /// values, matching `place_food_order`'s own
  /// `round(v_subtotal * v_tax_rate)::integer`.
  int? get tax {
    if (_items.isEmpty) return 0;
    final rate = pricing?.taxRate;
    if (rate == null) return null;
    return (subtotal * rate).round();
  }

  int? get deliveryFee {
    if (_items.isEmpty) return 0;
    return pricing?.deliveryFeeCents;
  }

  int? get total {
    final fee = deliveryFee;
    final taxValue = tax;
    if (fee == null || taxValue == null) return null;
    return subtotal + taxValue + fee;
  }

  String get _storageOwner => _ownerId ?? _guestOwner;

  Future<void> loadForOwner(String? ownerId) async {
    final generation = ++_loadGeneration;
    _ownerId = ownerId;
    _items.clear();
    _isLoading = true;
    notifyListeners();

    final loadedItems = await readCartLogged(
      _storage,
      _storageOwner,
      label: 'CartController',
    );
    if (generation != _loadGeneration) {
      return;
    }

    _items
      ..clear()
      ..addAll(loadedItems);
    _isLoading = false;
    notifyListeners();
    unawaited(_loadPricing());
  }

  /// Warms (or refreshes) [pricing] in the background; never throws. Called
  /// from [loadForOwner] (food has no separate catalog-load step the way
  /// grocery/pharmacy do) so pricing is ready well before a user reaches the
  /// cart/checkout screens.
  Future<void> _loadPricing() async {
    final loaded = await _pricingRepository.load(serviceId);
    if (loaded != null) {
      notifyListeners();
    }
  }

  Future<CartAddResult> addItem(
    CartItem item, {
    bool replaceRestaurantCart = false,

    /// Number of units to add. Must be at least 1.
    int quantity = 1,
  }) async {
    assert(quantity >= 1);
    final hasRestaurantConflict =
        _items.isNotEmpty && _items.first.restaurantId != item.restaurantId;

    if (hasRestaurantConflict && !replaceRestaurantCart) {
      return CartAddResult.restaurantConflict;
    }

    if (hasRestaurantConflict) {
      _items
        ..clear()
        ..add(item.copyWith(quantity: quantity.clamp(1, maximumQuantity)));
      notifyListeners();
      await _persist();
      return CartAddResult.replacedRestaurant;
    }

    final existingIndex = _items.indexWhere(
      (cartItem) => cartItem.menuItemId == item.menuItemId,
    );
    if (existingIndex == -1) {
      _items.add(item.copyWith(quantity: quantity.clamp(1, maximumQuantity)));
      notifyListeners();
      await _persist();
      return CartAddResult.added;
    }

    final existingItem = _items[existingIndex];
    if (existingItem.quantity >= maximumQuantity) {
      return CartAddResult.maximumReached;
    }

    _items[existingIndex] = existingItem.copyWith(
      quantity: math.min(existingItem.quantity + quantity, maximumQuantity),
    );
    notifyListeners();
    await _persist();
    return CartAddResult.quantityIncreased;
  }

  Future<void> increment(String menuItemId) async {
    final index = _indexOf(menuItemId);
    if (index == -1 || _items[index].quantity >= maximumQuantity) {
      return;
    }

    _items[index] = _items[index].copyWith(
      quantity: _items[index].quantity + 1,
    );
    notifyListeners();
    await _persist();
  }

  Future<void> decrement(String menuItemId) async {
    final index = _indexOf(menuItemId);
    if (index == -1 || _items[index].quantity <= 1) {
      return;
    }

    _items[index] = _items[index].copyWith(
      quantity: _items[index].quantity - 1,
    );
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String menuItemId) async {
    _items.removeWhere((item) => item.menuItemId == menuItemId);
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    if (_items.isEmpty) {
      return;
    }

    _items.clear();
    notifyListeners();
    final owner = _storageOwner;
    await _writeQueue.enqueue(() => _storage.clear(owner));
  }

  int _indexOf(String menuItemId) {
    return _items.indexWhere((item) => item.menuItemId == menuItemId);
  }

  Future<void> _persist() {
    final owner = _storageOwner;
    final snapshot = List<CartItem>.from(_items);
    return _writeQueue.enqueue(() => _storage.write(owner, snapshot));
  }
}
