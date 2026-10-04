import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../widgets/app_misc.dart';
import '../../../widgets/cart_view.dart';
import '../../../widgets/checkout_view.dart';
import 'cart_controller.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key, this.cartController});

  final CartController? cartController;

  @override
  Widget build(BuildContext context) {
    final controller = cartController ?? AppScope.of(context).cartController;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        void mutate(Future<void> Function() mutation) =>
            _runMutation(context, mutation);

        return CartView(
          showBackButton: false,
          isLoading: controller.isLoading,
          isEmpty: controller.isEmpty,
          emptyMessage: 'Your cart is empty',
          browseLabel: 'Browse restaurants',
          onBrowse: () => context.go(AppRoutes.food),
          storeName: controller.restaurantName,
          fallbackIcon: Icons.lunch_dining_rounded,
          lines: [
            for (final item in controller.items)
              CartLine(
                id: item.menuItemId,
                name: item.name,
                total: item.total,
                unitPrice: item.unitPrice,
                quantityLabel: '${item.quantity}',
                imageUrl: item.imageUrl,
                onDecrease: item.quantity == 1
                    ? null
                    : () => mutate(() => controller.decrement(item.menuItemId)),
                onIncrease: item.quantity == CartController.maximumQuantity
                    ? null
                    : () => mutate(() => controller.increment(item.menuItemId)),
                onRemove: () =>
                    mutate(() => controller.remove(item.menuItemId)),
              ),
          ],
          feeLines: [
            CheckoutLine('Subtotal', controller.subtotal),
            if (controller.tax case final tax?)
              CheckoutLine('Tax', tax)
            else
              const CheckoutLine.pending('Tax'),
            if (controller.deliveryFee case final fee?)
              CheckoutLine('Delivery fee', fee)
            else
              const CheckoutLine.pending('Delivery fee'),
          ],
          total: controller.total,
          onCheckout: () => context.push(AppRoutes.foodCheckout),
          onClear: () => mutate(controller.clear),
        );
      },
    );
  }

  Future<void> _runMutation(
    BuildContext context,
    Future<void> Function() mutation,
  ) async {
    try {
      await mutation();
    } on Object {
      if (!context.mounted) {
        return;
      }
      showCartSnackBar(
        context,
        'The cart changed, but it could not be saved for next time.',
      );
    }
  }
}
