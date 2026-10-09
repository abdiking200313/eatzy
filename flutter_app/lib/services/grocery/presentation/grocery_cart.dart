import 'dart:async';
import 'dart:collection';

import '../../shared/data/cart_storage.dart';
import '../models/grocery_models.dart';

/// Outcome of [GroceryCart.addProduct]. See its doc comment for what each
/// value means.
enum GroceryAddResult {
  added,
  quantityIncreased,
  unavailable,
  storeConflict,
  stockLimitReached,
}

/// Owns the grocery cart itself: its contents, the quantity-step rules for
/// adding/changing items, and persisting it to [CartStorage]. Cart/quantity
/// rules are kept separate from catalog loading (see `GroceryCatalog`) and
/// from checkout.
///
/// `GroceryController` owns everything this class doesn't: when to call
/// `notifyListeners`, pricing, and placing/confirming an order. This class
/// never calls `notifyListeners` itself -- the controller does that around
/// each mutating call.
class GroceryCart {
  GroceryCart({required CartStorage<GroceryCartLine> storage})
    : _storage = storage;

  static const String _guestOwner = 'guest';

  final CartStorage<GroceryCartLine> _storage;
  final CartWriteQueue _cartWriteQueue = CartWriteQueue(
    label: 'GroceryController',
  );
  final Map<String, GroceryCartLine> _lines = {};

  String? _ownerId;
  int _loadGeneration = 0;
  bool _isLoading = false;

  UnmodifiableListView<GroceryCartLine> get lines =>
      UnmodifiableListView(_lines.values.toList(growable: false));
  bool get isEmpty => _lines.isEmpty;
  bool get isNotEmpty => _lines.isNotEmpty;
  int get itemCount => _lines.length;
  String? get ownerId => _ownerId;
  bool get isLoading => _isLoading;

  /// The store whose products are currently in the cart, or `null` when
  /// empty. Every line shares the same store -- see [addProduct].
  String? get storeId =>
      _lines.isEmpty ? null : _lines.values.first.product.storeId;

  int get subtotal =>
      _lines.values.fold(0, (total, line) => total + line.total);

  String get _storageOwner => _ownerId ?? _guestOwner;

  /// Resolves once every cart write queued so far has been persisted. See
  /// `GroceryController.pendingCartWrite`, which forwards to this.
  Future<void> get pendingWrite => _cartWriteQueue.pending;

  /// Loads the persisted cart for [ownerId] (or the guest cart when `null`),
  /// replacing whatever cart is currently in memory, calling [onChanged]
  /// (the controller's `notifyListeners`) at the same two points the
  /// unextracted method did: once loading starts, and once it finishes.
  ///
  /// A monotonically increasing generation guards against a stale read
  /// finishing after a later account switch -- mirrors
  /// `CartController.loadForOwner`. Returns `false` (without calling
  /// [onChanged] a second time) when superseded by a later call, so the
  /// caller knows not to run anything that should only happen once this
  /// particular load actually finished (e.g. warming pricing).
  Future<bool> loadForOwner(
    String? ownerId, {
    required void Function() onChanged,
  }) async {
    final generation = ++_loadGeneration;
    _ownerId = ownerId;
    _lines.clear();
    _isLoading = true;
    onChanged();

    final loadedLines = await readCartLogged(
      _storage,
      _storageOwner,
      label: 'GroceryController',
    );
    if (generation != _loadGeneration) {
      return false;
    }

    _lines
      ..clear()
      ..addEntries(loadedLines.map((line) => MapEntry(line.product.id, line)));
    _isLoading = false;
    onChanged();
    return true;
  }

  /// Adds [steps] quantity steps of [product] (one item, or 0.5 kg per
  /// step) -- all or nothing: if that would exceed the available stock,
  /// nothing is added and [GroceryAddResult.stockLimitReached] is returned.
  ///
  /// A cart only ever holds lines from one store at a time: adding a
  /// product from a different store than [storeId] is refused with
  /// [GroceryAddResult.storeConflict] unless [replaceStoreCart] clears the
  /// existing cart first.
  GroceryAddResult addProduct(
    GroceryProduct product, {
    bool replaceStoreCart = false,
    int steps = 1,
  }) {
    assert(steps >= 1, 'steps must be at least 1');
    if (!product.isAvailable) {
      return GroceryAddResult.unavailable;
    }

    if (_lines.isNotEmpty && storeId != product.storeId && !replaceStoreCart) {
      return GroceryAddResult.storeConflict;
    }

    if (replaceStoreCart && storeId != product.storeId) {
      _lines.clear();
    }

    final existing = _lines[product.id];
    final nextQuantity =
        (existing?.quantity ?? 0) + product.quantityStep * steps;
    if (nextQuantity > product.availableQuantity) {
      return GroceryAddResult.stockLimitReached;
    }

    _lines[product.id] = GroceryCartLine(
      product: product,
      quantity: _normalizeQuantity(nextQuantity),
    );
    unawaited(_persist());
    return existing == null
        ? GroceryAddResult.added
        : GroceryAddResult.quantityIncreased;
  }

  /// Sets [productId]'s quantity to exactly [quantity], or removes it when
  /// [quantity] is zero or negative. Returns `false` (leaving the cart
  /// untouched) when [productId] isn't in the cart, [quantity] isn't a whole
  /// number of the product's quantity step, or it exceeds available stock.
  bool setQuantity(String productId, double quantity) {
    final existing = _lines[productId];
    if (existing == null) {
      return false;
    }

    if (quantity <= 0) {
      _lines.remove(productId);
      unawaited(_persist());
      return true;
    }

    final product = existing.product;
    final steps = quantity / product.quantityStep;
    final isValidStep = (steps - steps.round()).abs() < 0.0001;
    if (!isValidStep || quantity > product.availableQuantity) {
      return false;
    }

    _lines[productId] = existing.copyWith(
      quantity: _normalizeQuantity(quantity),
    );
    unawaited(_persist());
    return true;
  }

  bool increment(String productId) {
    final existing = _lines[productId];
    if (existing == null) {
      return false;
    }
    return setQuantity(
      productId,
      existing.quantity + existing.product.quantityStep,
    );
  }

  bool decrement(String productId) {
    final existing = _lines[productId];
    if (existing == null) {
      return false;
    }
    return setQuantity(
      productId,
      existing.quantity - existing.product.quantityStep,
    );
  }

  /// Removes [productId] entirely. Returns whether it was present.
  bool remove(String productId) {
    final removed = _lines.remove(productId) != null;
    if (removed) {
      unawaited(_persist());
    }
    return removed;
  }

  /// Clears the cart in memory only, without persisting the change. Used by
  /// `GroceryController.clear` (test-only reset).
  void clearInMemory() {
    _lines.clear();
  }

  /// Clears the cart and persists the now-empty cart. Used once an order is
  /// confirmed, so the next load doesn't restore the items that were just
  /// checked out.
  Future<void> clearAndPersist() {
    _lines.clear();
    return _persist();
  }

  double _normalizeQuantity(double quantity) =>
      (quantity * 100).roundToDouble() / 100;

  Future<void> _persist() {
    final owner = _storageOwner;
    final snapshot = _lines.values.toList(growable: false);
    return _cartWriteQueue.enqueue(() => _storage.write(owner, snapshot));
  }
}
