import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/grocery_models.dart';
import '../../../widgets/app_misc.dart';
import '../../../widgets/cart_view.dart';
import '../../../widgets/checkout_view.dart';
import 'grocery_controller.dart';

class GroceryCartScreen extends StatelessWidget {
  const GroceryCartScreen({
    super.key,
    this.controller,
    this.storeType = GroceryStoreType.grocery,
  });

  final GroceryController? controller;

  /// Grocery, Fresh Meat and Electronics each have their own cart.
  final GroceryStoreType storeType;

  GroceryController get _controller =>
      controller ?? GroceryController.forType(storeType);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final controller = _controller;
        return CartView(
          title: '${storeType.serviceName} cart',
          isEmpty: controller.isEmpty,
          emptyMessage:
              'Your ${storeType.serviceName.toLowerCase()} cart is empty',
          browseLabel: 'Browse stores',
          onBrowse: () => context.go(storeType.listRoute),
          storeName: controller.storeName,
          fallbackIcon: Icons.shopping_basket_outlined,
          lines: [
            for (final line in controller.cart)
              CartLine(
                id: line.product.id,
                name: line.product.name,
                total: line.total,
                unitPrice: line.product.unitPrice,
                quantityLabel: line.quantityLabel,
                imageUrl: line.product.imageUrl,
                onDecrease: () => controller.decrement(line.product.id),
                onIncrease: () {
                  if (!controller.increment(line.product.id)) {
                    showCartSnackBar(
                      context,
                      'No more ${line.product.name} is available.',
                    );
                  }
                },
                onRemove: () => controller.remove(line.product.id),
              ),
          ],
          feeLines: [
            CheckoutLine('Subtotal', controller.subtotal),
            CheckoutLine('Delivery fee', controller.deliveryFee),
          ],
          total: controller.total,
          onCheckout: () => context.push(storeType.checkoutRoute),
        );
      },
    );
  }
}
