import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_scaffold.dart';
import 'widgets/delivery_address_card.dart';
import 'widgets/order_summary_card.dart';

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key, this.cartController});

  final CartController? cartController;

  @override
  Widget build(BuildContext context) {
    final controller = cartController ?? CartController.instance;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => AppScaffold(
        title: 'Checkout',
        showBackButton: true,
        body: controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : controller.isEmpty
            ? const _EmptyCheckout()
            : ListView(
                padding: const EdgeInsets.all(TwSpacing.x5),
                children: [
                  OrderSummaryCard(
                    items: controller.items,
                    subtotal: controller.subtotal,
                    tax: controller.tax,
                    deliveryFee: controller.deliveryFee,
                    total: controller.total,
                  ),
                  const SizedBox(height: TwSpacing.x8),
                  DeliveryAddressCard(
                    onChangePressed: () => context.push(AppRoutes.addresses),
                  ),
                  const SizedBox(height: TwSpacing.x8),
                  GradientActionButton(
                    label: 'Continue to payment',
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Payment will be connected in the next step.',
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: TwSpacing.x8),
                ],
              ),
      ),
    );
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
            const Icon(
              Icons.remove_shopping_cart_outlined,
              size: 52,
              color: TwColors.primary,
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
