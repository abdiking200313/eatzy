import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/service_module.dart';
import '../../../platform/activity/models/activity_item.dart';
import '../../../platform/activity/presentation/activity_controller.dart';
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

class PharmacyController extends ChangeNotifier {
  PharmacyController({
    required PharmacyRepository repository,
    required ActivityController activityController,
    PharmacyOrderRepository? orderRepository,
    DateTime Function()? now,
  }) : _repository = repository,
       _activityController = activityController,
       _orderRepository = orderRepository,
       _now = now ?? DateTime.now;

  static final PharmacyController instance = () {
    final client = Supabase.instance.client;
    return PharmacyController(
      repository: SupabasePharmacyCatalogRepository(client: client),
      orderRepository: SupabasePharmacyOrderRepository(client: client),
      activityController: ActivityController.instance,
    );
  }();

  static const double deliveryFee = 2.50;

  /// How long a successful catalog load is considered fresh before
  /// [loadProducts] will silently refetch it again. A manual pull-to-refresh
  /// (via [loadProducts]'s `forceRefresh`) always bypasses this.
  static const Duration catalogStaleAfter = Duration(minutes: 5);

  final PharmacyRepository _repository;
  final ActivityController _activityController;
  final PharmacyOrderRepository? _orderRepository;
  final DateTime Function() _now;
  final List<PharmacyProduct> _products = [];
  final List<PharmacyCartItem> _cartItems = [];

  bool _isLoading = false;
  String? _loadError;
  DateTime? _lastLoadedAt;

  UnmodifiableListView<PharmacyProduct> get products =>
      UnmodifiableListView(_products);
  UnmodifiableListView<PharmacyCartItem> get cartItems =>
      UnmodifiableListView(_cartItems);
  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

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

  bool get isCartEmpty => _cartItems.isEmpty;
  bool get isCartNotEmpty => _cartItems.isNotEmpty;
  int get itemCount =>
      _cartItems.fold(0, (count, item) => count + item.quantity);
  double get subtotal =>
      _cartItems.fold(0, (total, item) => total + item.total);
  double get total => subtotal + (isCartEmpty ? 0 : deliveryFee);

  /// Loads the OTC catalog.
  ///
  /// By default this is a no-op once a catalog is already loaded and still
  /// fresh (see [isStale]), so cheap repeat calls (e.g. from `initState`)
  /// don't refetch pointlessly. Pass [forceRefresh] to always refetch —
  /// this is what a pull-to-refresh gesture should use, since it represents
  /// an explicit user request for the latest stock/prices regardless of
  /// staleness.
  Future<void> loadProducts({bool forceRefresh = false}) async {
    if (_isLoading) {
      return;
    }
    if (!forceRefresh && _products.isNotEmpty && !isStale) {
      return;
    }

    _isLoading = true;
    _loadError = null;
    notifyListeners();

    try {
      final products = await _repository.fetchProducts();
      _products
        ..clear()
        ..addAll(products.where((product) => product.isOverTheCounter));
      _lastLoadedAt = _now();
    } on Object {
      _loadError = 'The pharmacy catalog could not be loaded.';
    } finally {
      _isLoading = false;
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
      return PharmacyCartAddResult.added;
    }

    final item = _cartItems[index];
    if (item.quantity >= product.stockQuantity) {
      return PharmacyCartAddResult.maximumStockReached;
    }

    _cartItems[index] = item.copyWith(quantity: item.quantity + 1);
    notifyListeners();
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
  }

  void removeProduct(String productId) {
    final previousLength = _cartItems.length;
    _cartItems.removeWhere((item) => item.product.id == productId);
    if (_cartItems.length != previousLength) {
      notifyListeners();
    }
  }

  void clearCart() {
    if (_cartItems.isEmpty) {
      return;
    }
    _cartItems.clear();
    notifyListeners();
  }

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
  ) async {
    final validation = validateCheckout(details);
    if (!validation.isValid) {
      return PharmacyCheckoutResult.invalid(validation);
    }

    final confirmedAt = _now();
    final confirmedTotal = total;
    final confirmedItemCount = itemCount;
    String orderId;
    try {
      orderId =
          await _orderRepository?.placeOrder(
            PharmacyOrderRequest(
              details: details,
              items: _cartItems
                  .map(
                    (item) => PharmacyOrderLineInput(
                      productId: item.product.id,
                      quantity: item.quantity,
                    ),
                  )
                  .toList(growable: false),
            ),
          ) ??
          'pharmacy-${confirmedAt.microsecondsSinceEpoch}';
    } on Object {
      return PharmacyCheckoutResult.invalid(
        const PharmacyCheckoutValidation({
          'order': 'The pharmacy order could not be saved. Please try again.',
        }),
      );
    }

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
    clearCart();

    return PharmacyCheckoutResult.success(
      orderId: orderId,
      message:
          'Demo order confirmed. No payment was processed and no order '
          'was sent to a pharmacy.',
    );
  }

  int _indexOf(String productId) {
    return _cartItems.indexWhere((item) => item.product.id == productId);
  }
}
