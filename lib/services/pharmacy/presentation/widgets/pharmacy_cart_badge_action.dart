import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../widgets/cart_app_bar_action.dart';
import '../pharmacy_controller.dart';

/// Isolated so a cart mutation (add/increment/decrement/remove) only
/// rebuilds this small badge, not whatever (potentially long) list sits
/// underneath it in the app bar's screen. Shared by the pharmacy store-list
/// screen and the store-scoped catalog screen, both of which show the same
/// cart shortcut — mirrors `GroceryCartBadgeAction`.
class PharmacyCartBadgeAction extends StatelessWidget {
  const PharmacyCartBadgeAction({super.key, required this.controller});

  final PharmacyController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final itemCount = controller.itemCount;
        return CartAppBarAction(
          key: const ValueKey('pharmacy-cart-action'),
          itemCount: itemCount,
          tooltip: 'Pharmacy cart',
          onPressed: () => context.push(AppRoutes.pharmacyCart),
          icon: Icons.shopping_bag_rounded,
        );
      },
    );
  }
}
