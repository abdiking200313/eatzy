import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../platform/activity/presentation/activity_controller.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../../services/food/data/food_repository.dart';
import '../../../services/food/presentation/food_controller.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_scaffold.dart';
import 'widgets/delivery_address_card.dart';
import 'widgets/order_summary_card.dart';

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
  late final CartController _cartController =
      widget.cartController ?? CartController.instance;
  late final FoodController _foodController = FoodController(
    cartController: _cartController,
    orderRepository: widget.orderRepository,
    activityController: widget.activityController,
  );

  @override
  void dispose() {
    _foodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_cartController, _foodController]),
      builder: (context, _) => AppScaffold(
        title: 'Checkout',
        showBackButton: true,
        body: _cartController.isLoading
            ? const Center(child: CircularProgressIndicator())
            : _cartController.isEmpty
            ? const _EmptyCheckout()
            : ListView(
                padding: const EdgeInsets.all(TwSpacing.x5),
                children: [
                  OrderSummaryCard(
                    items: _cartController.items,
                    subtotal: _cartController.subtotal,
                    tax: _cartController.tax,
                    deliveryFee: _cartController.deliveryFee,
                    total: _cartController.total,
                  ),
                  const SizedBox(height: TwSpacing.x8),
                  DeliveryAddressCard(
                    onChangePressed: () => context.push(AppRoutes.addresses),
                  ),
                  const SizedBox(height: TwSpacing.x8),
                  if (_foodController.submissionError case final error?) ...[
                    Text(
                      error,
                      style: TwText.textSm().copyWith(color: TwColors.error),
                    ),
                    const SizedBox(height: TwSpacing.x3),
                  ],
                  GradientActionButton(
                    label: _foodController.isSubmitting
                        ? 'Saving order...'
                        : 'Place demo order',
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                    ),
                    onPressed: _foodController.isSubmitting
                        ? null
                        : _placeOrder,
                  ),
                  const SizedBox(height: TwSpacing.x8),
                ],
              ),
      ),
    );
  }

  Future<void> _placeOrder() async {
    final result = await _foodController.confirmOrder();
    if (result.isSuccess && mounted) {
      context.go(AppRoutes.activity);
    }
  }
}

class _EmptyCheckout extends StatelessWidget {
  const _EmptyCheckout();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TwSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.remove_shopping_cart_outlined,
              size: 52,
              color: context.serviceColors.accent,
            ),
            const SizedBox(height: TwSpacing.x4),
            Text('Your cart is empty', style: TwText.textXl()),
            const SizedBox(height: TwSpacing.x4),
            TextButton(
              onPressed: () => context.go(AppRoutes.mainApp),
              child: const Text('Browse restaurants'),
            ),
          ],
        ),
      ),
    );
  }
}
