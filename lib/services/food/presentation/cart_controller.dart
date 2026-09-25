import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../services/shared/data/cart_storage.dart';
import '../models/cart_item.dart';

enum CartAddResult {
  added,
  quantityIncreased,
  replacedRestaurant,
  restaurantConflict,
  maximumReached,
}

class CartController extends ChangeNotifier {
  CartController({required CartStorage<CartItem> storage}) : _storage = storage;

  static final CartController instance = CartController(
    storage: SharedPreferencesCartStorage<CartItem>(
      keyPrefix: 'zivo.cart.v1',
      toJson: (item) => item.toJson(),
      fromJson: CartItem.fromJson,
    ),
  );

  static const int maximumQuantity = 99;
  static const double taxRate = 0.10;

  /// In integer cents — see issue #8.
  static const int standardDeliveryFee = 499;
  static const String _guestOwner = 'guest';

  final CartStorage<CartItem> _storage;
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
  int get tax => (subtotal * taxRate).round();
  int get deliveryFee => _items.isEmpty ? 0 : standardDeliveryFee;
  int get total => subtotal + tax + deliveryFee;

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
