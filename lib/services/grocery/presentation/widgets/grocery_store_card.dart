import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import '../../../../widgets/app_misc.dart';
import '../../models/grocery_models.dart';

/// A tappable grocery store row on the store-list screen, analogous to
/// food's `RestaurantCard`: the store's photo as a square thumbnail (or a
/// storefront icon when it has none) beside its name and area.
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
    final productCount = store.products.length;
    return OutlinedCard(
      backgroundColor: TwColors.card,
      borderRadius: TwRadius.xl,
      borderColor: TwColors.border,
      onTap: onPressed,
      child: Row(
        children: [
          PhotoThumbnail(
            imageUrl: store.imageUrl,
            fallback: const ServiceIconChip(
              icon: Icons.storefront_rounded,
              iconSize: 28,
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
