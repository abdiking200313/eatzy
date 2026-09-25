import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../platform/activity/presentation/activity_controller.dart';
import '../../../widgets/checkout_view.dart';
import '../../shared/data/idempotency_key.dart';
import '../../shared/models/delivery_details.dart';
import '../data/food_repository.dart';
import 'cart_controller.dart';
import 'food_controller.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    this.cartController,
    this.orderRepository,
    this.activityController,
  });

  final CartController? cartController;
  final FoodOrderRepository? orderRepository;
  final ActivityController? activityController;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _noteController = TextEditingController();

  late final CartController _cartController =
      widget.cartController ?? CartController.instance;
  late final FoodController _foodController = FoodController(
    cartController: _cartController,
    orderRepository: widget.orderRepository,
    activityController: widget.activityController,
  );

  /// Identifies this checkout attempt (issue #59): generated once when this
  /// screen is first built and reused for every retry on this same visit,
  /// so a lost response followed by a retry collapses into the original
  /// order server-side instead of creating a duplicate. A fresh visit to
  /// checkout (a new instance of this screen) gets a fresh key.
  final String _idempotencyKey = generateIdempotencyKey();

  @override
  void dispose() {
    _noteController.dispose();
    _foodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_cartController, _foodController]),
      builder: (context, _) => CheckoutView(
        title: 'Checkout',
        isLoading: _cartController.isLoading,
        isEmpty: _cartController.isEmpty,
        emptyMessage: 'Your cart is empty',
        browseLabel: 'Browse restaurants',
        onBrowse: () => context.go(AppRoutes.mainApp),
        noteController: _noteController,
        itemLines: [
          for (final item in _cartController.items)
            CheckoutLine('${item.name} ×${item.quantity}', item.total),
        ],
        feeLines: [
          CheckoutLine('Subtotal', _cartController.subtotal),
          CheckoutLine('Tax', _cartController.tax),
          CheckoutLine('Delivery fee', _cartController.deliveryFee),
        ],
        total: _cartController.total,
        isSubmitting: _foodController.isSubmitting,
        errorText: _foodController.submissionError,
        onSubmit: _placeOrder,
      ),
    );
  }

  Future<void> _placeOrder() async {
    final result = await _foodController.confirmOrder(
      delivery: DeliveryDetails(note: _noteController.text),
      idempotencyKey: _idempotencyKey,
    );
    if (!result.isSuccess || !mounted) {
      return;
    }
    await showOrderPlacedDialog(
      context,
      orderId: result.orderId!,
      message: 'Your order was sent to the restaurant. Pay on delivery.',
    );
    if (mounted) {
      context.go(AppRoutes.activity);
    }
  }
}
