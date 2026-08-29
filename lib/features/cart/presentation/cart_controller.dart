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
  static const double standardDeliveryFee = 4.99;
  static const String _guestOwner = 'guest';

  final CartStorage<CartItem> _storage;
  final List<CartItem> _items = [];

  Future<void> _pendingWrite = Future<void>.value();
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
  double get subtotal => _items.fold(0, (total, item) => total + item.total);
  double get tax => subtotal * taxRate;
  double get deliveryFee => _items.isEmpty ? 0 : standardDeliveryFee;
  double get total => subtotal + tax + deliveryFee;

  String get _storageOwner => _ownerId ?? _guestOwner;

  Future<void> loadForOwner(String? ownerId) async {
    final generation = ++_loadGeneration;
    _ownerId = ownerId;
    _items.clear();
    _isLoading = true;
    notifyListeners();

    List<CartItem> loadedItems;
    try {
      loadedItems = await _storage.read(_storageOwner);
    } on Object {
      loadedItems = const [];
    }
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
  }) async {
    final hasRestaurantConflict =
        _items.isNotEmpty && _items.first.restaurantId != item.restaurantId;

    if (hasRestaurantConflict && !replaceRestaurantCart) {
      return CartAddResult.restaurantConflict;
    }

    if (hasRestaurantConflict) {
      _items
        ..clear()
        ..add(item.copyWith(quantity: 1));
      notifyListeners();
      await _persist();
      return CartAddResult.replacedRestaurant;
    }

    final existingIndex = _items.indexWhere(
      (cartItem) => cartItem.menuItemId == item.menuItemId,
    );
    if (existingIndex == -1) {
      _items.add(item.copyWith(quantity: 1));
      notifyListeners();
      await _persist();
      return CartAddResult.added;
    }

    final existingItem = _items[existingIndex];
    if (existingItem.quantity >= maximumQuantity) {
      return CartAddResult.maximumReached;
    }

    _items[existingIndex] = existingItem.copyWith(
      quantity: existingItem.quantity + 1,
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
    await _queueWrite(() => _storage.clear(owner));
  }

  int _indexOf(String menuItemId) {
    return _items.indexWhere((item) => item.menuItemId == menuItemId);
  }

  Future<void> _persist() {
    final owner = _storageOwner;
    final snapshot = List<CartItem>.from(_items);
    return _queueWrite(() => _storage.write(owner, snapshot));
  }

  Future<void> _queueWrite(Future<void> Function() write) {
    final previousWrite = _pendingWrite;
    final operation = () async {
      try {
        await previousWrite;
      } on Object {
        // A later cart change should still get a chance to persist.
      }
      await write();
    }();
    _pendingWrite = operation;
    return operation;
  }
}
