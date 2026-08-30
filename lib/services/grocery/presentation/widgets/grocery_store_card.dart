import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import '../../../../widgets/app_misc.dart';
import '../../models/grocery_models.dart';

/// A tappable grocery store row on the store-list screen, analogous to
/// food's `RestaurantCard`. Grocery stores have no logo/hero image in the
/// current schema, so this stays a compact text-only row rather than
/// mirroring `RestaurantCard`'s image header.
class GroceryStoreCard extends StatelessWidget {
  const GroceryStoreCard({
    super.key,
    required this.store,
    required this.onPressed,
  });

  final GroceryStore store;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    final productCount = store.products.length;
    return OutlinedCard(
      backgroundColor: TwColors.card,
      borderRadius: TwRadius.xl,
      borderColor: TwColors.border,
      onTap: onPressed,
      child: Row(
        children: [
          Container(
            width: ServiceIconChip.size,
            height: ServiceIconChip.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.accent,
              borderRadius: BorderRadius.circular(TwRadius.lg),
            ),
            child: Icon(
              Icons.storefront_rounded,
              color: palette.onAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: TwSpacing.rhythmDefault),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TwText.textXl,
                ),
                const SizedBox(height: TwSpacing.rhythmTight),
                Text(
                  store.area,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TwText.textSm.copyWith(color: TwColors.textMuted),
                ),
                const SizedBox(height: TwSpacing.rhythmTight),
                Text(
                  '$productCount ${productCount == 1 ? 'product' : 'products'}',
                  style: TwText.textXs.copyWith(color: TwColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: TwSpacing.x2),
          const Icon(Icons.chevron_right_rounded, color: TwColors.textMuted),
        ],
      ),
    );
  }
}
