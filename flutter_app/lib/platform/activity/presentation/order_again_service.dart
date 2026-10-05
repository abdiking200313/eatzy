import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/service_module.dart';
import '../../../services/food/presentation/cart_controller.dart';
import '../../../services/grocery/models/grocery_models.dart';
import '../../../services/grocery/presentation/grocery_controller.dart';
import '../../../services/pharmacy/presentation/pharmacy_controller.dart';
import '../data/order_again_repository.dart';
import '../models/activity_item.dart';

/// "Order again" from Activity: loads a past order's still-available items
/// ([OrderAgainRepository]) and puts them into that vertical's cart,
/// replacing whatever the cart held (the Activity screen asks first when
/// the cart isn't empty).
class OrderAgainService {
  OrderAgainService({
    AppServices? appServices,
    OrderAgainRepository? repository,
    CartController? foodCart,
    GroceryController? grocery,
    PharmacyController? pharmacy,
  }) : _appServices = appServices,
       _repository = repository,
       _foodCartOverride = foodCart,
       _groceryOverride = grocery,
       _pharmacyOverride = pharmacy;

  // Resolved lazily off [_appServices] (via `AppScope.of(context)` at the
  // call site) so a caller that already holds every cart it needs (e.g. a
  // test) never has to supply one -- see `_foodCart`/`_grocery`/`_pharmacy`
  // below.
  final AppServices? _appServices;
  final OrderAgainRepository? _repository;

  final CartController? _foodCartOverride;
  final GroceryController? _groceryOverride;
  final PharmacyController? _pharmacyOverride;
  CartController get _foodCart =>
      _foodCartOverride ?? _appServices!.cartController;
  GroceryController _grocery(GroceryStoreType type) =>
      _groceryOverride ?? _appServices!.groceryController(type);
  PharmacyController get _pharmacy =>
      _pharmacyOverride ?? _appServices!.pharmacyController;

  OrderAgainRepository get _source =>
      _repository ??
      SupabaseOrderAgainRepository(client: _appServices!.supabaseClient);

  /// Whether this row is a real order that can be placed again.
  static bool canReorder(ActivityItem item) =>
      item.serviceId != ServiceId.unknown;

  Future<ReorderBasket?> loadBasket(ActivityItem item) =>
      _source.loadBasket(serviceId: item.serviceId, orderId: item.id);

  /// Whether filling [basket] would replace items already in a cart.
  bool wouldReplaceCart(ReorderBasket basket) => switch (basket) {
    FoodReorderBasket() => _foodCart.isNotEmpty,
    GroceryReorderBasket(:final storeType) => _grocery(storeType).isNotEmpty,
    PharmacyReorderBasket() => _pharmacy.isCartNotEmpty,
  };

  /// Replaces the matching cart's contents with [basket] and returns the
  /// route of that cart.
  Future<String> fillCart(ReorderBasket basket) async {
    switch (basket) {
      case FoodReorderBasket(:final items):
        await _foodCart.clear();
        for (final item in items) {
          await _foodCart.addItem(item, quantity: item.quantity);
        }
        return AppRoutes.foodCart;
      case GroceryReorderBasket(:final lines, :final storeType):
        final grocery = _grocery(storeType);
        for (final line in List.of(grocery.cart)) {
          grocery.remove(line.product.id);
        }
        for (final (:product, :quantity) in lines) {
          grocery.addProduct(product);
          // Falls back to one step when the past quantity isn't a valid
          // step of today's product (e.g. its step size changed).
          grocery.setQuantity(product.id, quantity);
        }
        return storeType.cartRoute;
      case PharmacyReorderBasket(:final lines):
        _pharmacy.clearCart();
        for (final (:product, :quantity) in lines) {
          _pharmacy.addProduct(product, quantity: quantity);
        }
        return AppRoutes.pharmacyCart;
    }
  }
}
