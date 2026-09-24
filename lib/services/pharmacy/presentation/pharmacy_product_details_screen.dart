import 'package:flutter/material.dart';

import '../../../app/service_module.dart';
import '../../../config/theme.dart';
import '../../../platform/localization/app_money.dart';
import '../../../widgets/product_details_view.dart';
import '../models/pharmacy_product.dart';

/// Full-screen details for one pharmacy product, opened by tapping its row
/// in the pharmacy catalog. [inCartQuantity] is how many are already in the
/// cart, so the quantity picker can't go past the remaining stock.
class PharmacyProductDetailsScreen extends StatelessWidget {
  const PharmacyProductDetailsScreen({
    super.key,
    required this.product,
    required this.inCartQuantity,
    required this.onAddToCart,
  });

  final PharmacyProduct product;
  final int inCartQuantity;

  /// Called with the number of units to add.
  final ValueChanged<int> onAddToCart;

  @override
  Widget build(BuildContext context) {
    final remaining = product.isAvailable
        ? product.stockQuantity - inCartQuantity
        : 0;

    return ZivoServiceTheme(
      serviceId: ServiceId.pharmacy,
      child: ProductDetailsView(
        imageUrl: product.imageUrl,
        fallback: Icon(
          Icons.medication_outlined,
          size: 96,
          color: TwColors.textMuted,
        ),
        eyebrow: product.category,
        name: product.name,
        priceLabel: AppMoney.formatCents(product.unitPrice),
        stockLabel: !product.isAvailable
            ? 'Out of stock'
            : product.isLowStock
            ? 'Only ${product.stockQuantity} left'
            : 'In stock',
        isInStock: product.isAvailable,
        description: product.description,
        facts: const ['Over the counter -- no prescription needed.'],
        maxSteps: remaining,
        unavailableLabel: product.isAvailable
            ? 'All stock in cart'
            : 'Out of stock',
        quantityLabel: (steps) => '$steps',
        onAddToCart: onAddToCart,
      ),
    );
  }
}
