import 'package:flutter/material.dart';

import '../cart_controller.dart';

/// `RestaurantScreen`'s "View cart" floating action button. Hidden while
/// [controller] is empty; otherwise shows the current item count and calls
/// [onViewCart] (navigates to the cart screen) when pressed.
class RestaurantCartFab extends StatelessWidget {
  const RestaurantCartFab({
    super.key,
    required this.controller,
    required this.onViewCart,
  });

  final CartController controller;
  final VoidCallback onViewCart;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.itemCount == 0) {
          return const SizedBox.shrink();
        }
        return FloatingActionButton.extended(
          onPressed: onViewCart,
          icon: Badge(
            label: Text('${controller.itemCount}'),
            child: const Icon(Icons.shopping_cart_outlined),
          ),
          label: const Text('View cart'),
        );
      },
    );
  }
}
