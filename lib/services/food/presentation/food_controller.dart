import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_routes.dart';
import '../../../app/service_module.dart';
import 'cart_controller.dart';
import '../../../platform/activity/models/activity_item.dart';
import '../../../platform/activity/presentation/activity_controller.dart';
import '../../shared/data/idempotency_key.dart';
import '../../shared/data/rpc_helpers.dart';
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
  List<String> _addressErrors = const [];

  bool get isSubmitting => _isSubmitting;
  String? get submissionError => _submissionError;
  List<String> get addressErrors => _addressErrors;

  FoodOrderRepository get _repository =>
      _orderRepository ??
      SupabaseFoodOrderRepository(client: Supabase.instance.client);

  /// Validates the cart, places the order through the shared
  /// [confirmDemoOrder] flow, records activity, and clears the cart.
  ///
  /// When the cart has no restaurant selected or no items, this is a no-op
  /// (matching the previous inline guard clause) and no submission state is
  /// touched. Likewise a no-op — without touching submission state — while a
  /// previous call is still in flight (see [isSubmitting]): this is a
  /// belt-and-braces guard against a double-tap or a second programmatic
  /// call racing the first one, on top of the checkout screen already
  /// disabling its submit button while [isSubmitting] is true.
  ///
  /// [idempotencyKey] identifies this checkout *attempt* (issue #59) and is
  /// forwarded to `place_food_order` so a retried submission (the same key)
  /// returns the existing order instead of creating a duplicate. Callers
  /// should generate one per attempt (e.g. once per checkout screen visit)
  /// and keep passing the same value across retries of that attempt; when
  /// omitted, a fresh key is generated for this call only, which gives no
  /// protection against a retry that calls this method again.
  Future<FoodCheckoutResult> confirmOrder(
    FoodDeliveryAddress address, {
    String? idempotencyKey,
  }) async {
    if (_isSubmitting) {
      return FoodCheckoutResult.invalid(const []);
    }

    final restaurantId = _cartController.restaurantId;
    final items = _cartController.items;
    final hasOrder = restaurantId != null && items.isNotEmpty;

    if (!hasOrder) {
      return FoodCheckoutResult.invalid(const []);
    }

    final addressErrors = _validateAddress(address);
    if (addressErrors.isNotEmpty) {
      _addressErrors = addressErrors;
      _submissionError = null;
      notifyListeners();
      return FoodCheckoutResult.invalid(addressErrors);
    }

    _isSubmitting = true;
    _submissionError = null;
    _addressErrors = const [];
    notifyListeners();

    final result =
        await confirmDemoOrder<FoodCheckoutResult, bool, PlacedOrder>(
          validation: hasOrder,
          isValid: (isValid) => isValid,
          onInvalid: (_) => FoodCheckoutResult.invalid(const []),
          placeOrder: () => _repository.placeOrder(
            FoodOrderRequest(
              restaurantId: restaurantId,
              address: address,
              items: [
                for (final item in items)
                  FoodOrderLineInput(
                    menuItemId: item.menuItemId,
                    quantity: item.quantity,
                  ),
              ],
              idempotencyKey: idempotencyKey ?? generateIdempotencyKey(),
            ),
          ),
          // No real repository is ever configured out from under `_repository`
          // (it defaults to a live Supabase-backed one — see its getter above),
          // so this only matters for a caller that injects `null`-returning
          // test doubles; it mirrors the client-side estimate the cart screen
          // already showed, since no server round trip actually happened.
          fallbackOrder: () => PlacedOrder(
            orderId: 'food-${DateTime.now().microsecondsSinceEpoch}',
            subtotal: _cartController.subtotal,
            deliveryFee: _cartController.deliveryFee,
            tax: _cartController.tax,
            total: _cartController.total,
          ),
          onSaveFailed: (error, stackTrace) {
            debugPrint(
              'FoodController.confirmOrder failed: $error\n$stackTrace',
            );
            return FoodCheckoutResult.invalid(const [
              'The food order could not be saved. Please try again.',
            ]);
          },
          // `order.total` is the RPC's authoritative, server-computed total
          // (issue #60) — not `_cartController.total`, which can be stale if a
          // menu price changed between the cart being built and this checkout
          // being confirmed.
          recordActivity: (order) => _activityController.record(
            ActivityItem(
              id: order.orderId,
              serviceId: ServiceId.food,
              title: _cartController.restaurantName ?? 'Food order',
              subtitle:
                  '${items.length} ${items.length == 1 ? 'item' : 'items'} • '
                  '${address.city}',
              status: 'Confirmed',
              occurredAt: DateTime.now(),
              amount: order.total,
              detailsRoute: AppRoutes.food,
              paymentMethod: 'cash_on_delivery',
              paymentStatus: 'pending_collection',
            ),
          ),
          clearCart: _cartController.clear,
          onConfirmed: (order) => FoodCheckoutResult.confirmed(order.orderId),
        );

    _submissionError = result.isSuccess
        ? null
        : (result.errors.isEmpty ? null : result.errors.first);
    _isSubmitting = false;
    notifyListeners();
    return result;
  }

  List<String> _validateAddress(FoodDeliveryAddress address) {
    final errors = <String>[];
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
    return errors;
  }
}
