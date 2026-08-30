import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../platform/localization/app_money.dart';
import '../../../../widgets/add_to_cart_button.dart';
import '../../../../widgets/app_cards.dart';
import '../../../../widgets/app_misc.dart';
import '../../models/grocery_models.dart';

/// A single grocery product row, shown inside a store's scoped catalog.
class GroceryProductCard extends StatelessWidget {
  const GroceryProductCard({
    super.key,
    required this.product,
    required this.onAdd,
  });

  final GroceryProduct product;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    final stockLabel = switch (product.stockState) {
      GroceryStockState.inStock => 'In stock',
      GroceryStockState.lowStock => 'Low stock',
      GroceryStockState.outOfStock => 'Out of stock',
    };
    final stockPillColors = switch (product.stockState) {
      GroceryStockState.inStock => (
        bg: TwColors.tertiary.withOpacityValue(0.14),
        fg: const Color(0xFF0F7A54),
      ),
      GroceryStockState.lowStock => (
        bg: const Color(0xFFFFF1D6),
        fg: Colors.orange.shade800,
      ),
      GroceryStockState.outOfStock => (
        bg: TwColors.errorSoft,
        fg: TwColors.error,
      ),
    };

    // White card only (dimmed to neutral stone for the unavailable state);
    // the per-service accent is confined to the 48px icon chip.
    return OutlinedCard(
      backgroundColor: product.isAvailable ? TwColors.card : TwColors.stone100,
      borderColor: product.isAvailable ? TwColors.border : TwColors.stone300,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: ServiceIconChip.size,
            height: ServiceIconChip.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: product.isAvailable ? palette.accent : TwColors.stone300,
              borderRadius: BorderRadius.circular(TwRadius.lg),
            ),
            child: Text(product.icon, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: TwSpacing.rhythmDefault),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: TwText.fontBoldBase),
                Text(product.description, style: TwText.textSm),
                const SizedBox(height: TwSpacing.rhythmTight),
                Text(
                  '${AppMoney.format(product.unitPrice)} ${product.unitLabel}',
                  style: TwText.fontBoldSm,
                ),
                const SizedBox(height: TwSpacing.rhythmTight),
                StatusPill(
                  label: stockLabel,
                  backgroundColor: stockPillColors.bg,
                  foregroundColor: stockPillColors.fg,
                ),
              ],
            ),
          ),
          AddToCartButton(
            key: ValueKey('add-grocery-${product.id}'),
            tooltip: product.isAvailable ? 'Add ${product.name}' : stockLabel,
            onPressed: product.isAvailable ? onAdd : null,
          ),
        ],
      ),
    );
  }
}
