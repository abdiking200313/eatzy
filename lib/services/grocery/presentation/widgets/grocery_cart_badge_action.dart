import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../widgets/cart_app_bar_action.dart';
import '../grocery_controller.dart';

/// Isolated so an add-to-cart tap only rebuilds this small badge, not
/// whatever (potentially long) list sits underneath it in the app bar's
/// screen. Shared by the grocery store-list screen and the store-scoped
/// catalog screen, both of which show the same cart shortcut.
class GroceryCartBadgeAction extends StatelessWidget {
  const GroceryCartBadgeAction({super.key, required this.controller});

  final GroceryController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final itemCount = controller.itemCount;
        return CartAppBarAction(
          itemCount: itemCount,
          tooltip: 'Grocery cart ($itemCount)',
          onPressed: () => context.push(AppRoutes.groceryCart),
          icon: Icons.shopping_basket_rounded,
        );
      },
    );
  }
}
