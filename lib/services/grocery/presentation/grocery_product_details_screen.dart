import 'package:flutter/material.dart';

import '../../../app/service_module.dart';
import '../../../config/theme.dart';
import '../../../platform/localization/app_money.dart';
import '../../../widgets/product_details_view.dart';
import '../models/grocery_models.dart';

/// Full-screen details for one grocery product, opened by tapping its row
/// in the store catalog. [inCartQuantity] is how much of it is already in
/// the cart, so the quantity picker can't go past the remaining stock.
class GroceryProductDetailsScreen extends StatelessWidget {
  const GroceryProductDetailsScreen({
    super.key,
    required this.product,
    required this.inCartQuantity,
    required this.onAddToCart,
    this.storeType = GroceryStoreType.grocery,
  });

  /// Picks the palette (Grocery / Fresh Meat / Electronics).
  final GroceryStoreType storeType;

  final GroceryProduct product;
  final double inCartQuantity;

  /// Called with the number of quantity steps to add (see
  /// `GroceryController.addProduct`'s `steps`).
  final ValueChanged<int> onAddToCart;

  @override
  Widget build(BuildContext context) {
    final step = product.quantityStep;
    final remaining = product.isAvailable
        ? product.availableQuantity - inCartQuantity
        : 0.0;
    // Tolerance guards against float error in e.g. 2.5 / 0.5.
    final maxSteps = (remaining / step + 1e-9).floor();
    final isByWeight = product.pricingUnit == GroceryPricingUnit.kilogram;

    return ZivoServiceTheme(
      serviceId: ServiceId.grocery,
      palette: storeType.palette,
      child: ProductDetailsView(
        imageUrl: product.imageUrl,
        fallback: Text(product.icon, style: const TextStyle(fontSize: 96)),
        name: product.name,
        priceLabel:
            '${AppMoney.formatCents(product.unitPrice)} ${product.unitLabel}',
        stockLabel: switch (product.stockState) {
          GroceryStockState.inStock => 'In stock',
          GroceryStockState.lowStock => 'Low stock',
          GroceryStockState.outOfStock => 'Out of stock',
        },
        isInStock: product.isAvailable,
        description: product.description,
        facts: [if (isByWeight) 'Sold by weight, in 0.5 kg steps.'],
        maxSteps: maxSteps,
        unavailableLabel: product.isAvailable
            ? 'All stock in cart'
            : 'Out of stock',
        quantityLabel: (steps) {
          if (!isByWeight) return '$steps';
          final kg = steps * step;
          return '${kg == kg.roundToDouble() ? kg.toInt() : kg} kg';
        },
        onAddToCart: onAddToCart,
      ),
    );
  }
}
