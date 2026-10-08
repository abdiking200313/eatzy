import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../widgets/cart_view.dart';
import '../../../widgets/checkout_view.dart';
import 'pharmacy_controller.dart';

class PharmacyCartScreen extends StatelessWidget {
  const PharmacyCartScreen({super.key, this.controller});

  final PharmacyController? controller;

  @override
  Widget build(BuildContext context) {
    final pharmacyController =
        controller ?? AppScope.of(context).pharmacyController;

    return AnimatedBuilder(
      animation: pharmacyController,
      builder: (context, _) {
        return CartView(
          isEmpty: pharmacyController.isCartEmpty,
          emptyMessage: 'Your pharmacy cart is empty',
          browseLabel: 'Browse pharmacy',
          onBrowse: () => context.go(AppRoutes.pharmacy),
          notice:
              'Your pharmacy cart is separate from food and grocery. '
              'All listed products are OTC.',
          fallbackIcon: Icons.medication_outlined,
          lines: [
            for (final item in pharmacyController.cartItems)
              CartLine(
                id: item.product.id,
                name: item.product.name,
                total: item.total,
                unitPrice: item.product.unitPrice,
                quantityLabel: '${item.quantity}',
                imageUrl: item.product.imageUrl,
                onDecrease: () => pharmacyController.decrement(item.product.id),
                onIncrease: item.quantity < item.product.stockQuantity
                    ? () => pharmacyController.increment(item.product.id)
                    : null,
                onRemove: () =>
                    pharmacyController.removeProduct(item.product.id),
              ),
          ],
          feeLines: [
            CheckoutLine('Subtotal', pharmacyController.subtotal),
            if (pharmacyController.deliveryFee case final fee?)
              CheckoutLine('Delivery fee', fee)
            else
              const CheckoutLine.pending('Delivery fee'),
          ],
          total: pharmacyController.total,
          onCheckout: () => context.push(AppRoutes.pharmacyCheckout),
          onClear: pharmacyController.clearCart,
        );
      },
    );
  }
}
