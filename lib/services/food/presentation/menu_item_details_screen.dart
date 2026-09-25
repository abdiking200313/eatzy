import 'package:flutter/material.dart';

import '../../../app/service_module.dart';
import '../../../config/theme.dart';
import '../../../platform/localization/app_money.dart';
import '../../../widgets/product_details_view.dart';
import '../models/restaurant_menu.dart';
import 'cart_controller.dart';

/// A full-screen "more info" page for a single menu item, reached by
/// tapping its card in [RestaurantScreen] (not the card's own add-to-cart
/// button, which still adds instantly without navigating here). Not a
/// go_router route — like a bottom sheet or dialog, this is only ever
/// reached by a direct push from the one place that already holds the full
/// [MenuItem], so it doesn't need a shareable/deep-linkable URL. A thin
/// wrapper around the shared [ProductDetailsView], the same as
/// `GroceryProductDetailsScreen`/`PharmacyProductDetailsScreen`.
class MenuItemDetailsScreen extends StatelessWidget {
  const MenuItemDetailsScreen({
    super.key,
    required this.item,
    required this.onAddToCart,
  });

  final MenuItem item;

  /// Called with the chosen quantity after this page has closed.
  final ValueChanged<int> onAddToCart;

  @override
  Widget build(BuildContext context) {
    return ZivoServiceTheme(
      serviceId: ServiceId.food,
      child: ProductDetailsView(
        imageUrl: item.imageUrl,
        fallback: Icon(
          Icons.lunch_dining_rounded,
          size: 96,
          color: context.serviceColors.accent,
        ),
        name: item.name,
        priceLabel: AppMoney.formatCents(item.price),
        description: item.description,
        maxSteps: CartController.maximumQuantity,
        quantityLabel: (steps) => '$steps',
        onAddToCart: onAddToCart,
      ),
    );
  }
}
