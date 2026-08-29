import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_routes.dart';
import '../../../app/service_module.dart';
import '../../../features/cart/presentation/cart_controller.dart';
import '../../../platform/activity/models/activity_item.dart';
import '../../../platform/activity/presentation/activity_controller.dart';
import '../../shared/presentation/confirm_order_flow.dart';
import '../data/food_repository.dart';
import '../models/food_models.dart';

/// The outcome of [FoodController.confirmOrder], mirroring the
/// `GroceryCheckoutResult`/`PharmacyCheckoutResult` shape.
class FoodCheckoutResult {
  const FoodCheckoutResult._({
    required this.isSuccess,
    this.orderId,
    this.errors = const [],
  });

  factory FoodCheckoutResult.confirmed(String orderId) =>
      FoodCheckoutResult._(isSuccess: true, orderId: orderId);

  factory FoodCheckoutResult.invalid(List<String> errors) =>
      FoodCheckoutResult._(isSuccess: false, errors: List.unmodifiable(errors));

  final bool isSuccess;
  final String? orderId;
  final List<String> errors;
}

/// Owns food checkout/order-placement state, mirroring the
/// `GroceryController`/`PharmacyController` pattern (issue #4).
///
/// Unlike grocery and pharmacy, food's *cart* stays owned by the app-wide
/// [CartController] — only the checkout/order-placement logic that used to
/// live inline in `CheckoutScreen`'s `State` moves here. Because of that,
/// this controller holds no cross-screen state of its own (no cart, no
/// catalog) beyond the transient submission status for a single checkout
/// attempt, so — deliberately unlike `GroceryController.instance` /
/// `PharmacyController.instance` — it does not expose a static `instance`
/// singleton: a shared singleton would leak a stale `submissionError`
/// across separate visits to the checkout screen, which the previous
/// per-`State` fields never did. `CheckoutScreen` constructs its own
/// `FoodController` scoped to its own lifetime instead.
class FoodController extends ChangeNotifier {
  FoodController({
    required CartController cartController,
    FoodOrderRepository? orderRepository,
    ActivityController? activityController,
  }) : _cartController = cartController,
       _orderRepository = orderRepository,
       _activityController = activityController ?? ActivityController.instance;

  final CartController _cartController;
  final FoodOrderRepository? _orderRepository;
  final ActivityController _activityController;

  bool _isSubmitting = false;
  String? _submissionError;

  bool get isSubmitting => _isSubmitting;
  String? get submissionError => _submissionError;

  FoodOrderRepository get _repository =>
      _orderRepository ??
      SupabaseFoodOrderRepository(client: Supabase.instance.client);

  /// Validates the cart, places the order through the shared
  /// [confirmDemoOrder] flow, records activity, and clears the cart.
  ///
  /// When the cart has no restaurant selected or no items, this is a no-op
  /// (matching the previous inline guard clause) and no submission state is
  /// touched.
  Future<FoodCheckoutResult> confirmOrder() async {
    final restaurantId = _cartController.restaurantId;
    final items = _cartController.items;
    final hasOrder = restaurantId != null && items.isNotEmpty;

    if (!hasOrder) {
      return FoodCheckoutResult.invalid(const []);
    }

    _isSubmitting = true;
    _submissionError = null;
    notifyListeners();

    final result = await confirmDemoOrder<FoodCheckoutResult, bool>(
      validation: hasOrder,
      isValid: (isValid) => isValid,
      onInvalid: (_) => FoodCheckoutResult.invalid(const []),
      placeOrder: () => _repository.placeOrder(
        FoodOrderRequest(
          restaurantId: restaurantId,
          items: [
            for (final item in items)
              FoodOrderLineInput(
                menuItemId: item.menuItemId,
                quantity: item.quantity,
              ),
          ],
        ),
      ),
      fallbackOrderId: () => 'food-${DateTime.now().microsecondsSinceEpoch}',
      onSaveFailed: () => FoodCheckoutResult.invalid(const [
        'The food order could not be saved. Please try again.',
      ]),
      recordActivity: (orderId) => _activityController.record(
        ActivityItem(
          id: orderId,
          serviceId: ServiceId.food,
          title: _cartController.restaurantName ?? 'Food order',
          subtitle: 'Demo order • Somalia',
          status: 'Confirmed',
          occurredAt: DateTime.now(),
          amount: _cartController.total,
          detailsRoute: AppRoutes.food,
        ),
      ),
      clearCart: _cartController.clear,
      onConfirmed: FoodCheckoutResult.confirmed,
    );

    _submissionError = result.isSuccess
        ? null
        : (result.errors.isEmpty ? null : result.errors.first);
    _isSubmitting = false;
    notifyListeners();
    return result;
  }
}
