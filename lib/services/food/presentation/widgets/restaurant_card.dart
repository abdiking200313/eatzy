import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import '../../../../widgets/app_misc.dart';
import '../../models/restaurant.dart';

/// A tappable restaurant row on the restaurant-list screen, styled to match
/// `GroceryStoreCard`/pharmacy's store rows (compact icon chip + text, no
/// photo header) rather than a photo-forward card — kept in sync so the
/// three verticals' store-list screens read as one consistent pattern.
class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onPressed,
  });

  final Restaurant restaurant;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
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
              Icons.restaurant_rounded,
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
                  restaurant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TwText.textXl,
                ),
                if (restaurant.description.trim().isNotEmpty) ...[
                  const SizedBox(height: TwSpacing.rhythmTight),
                  Text(
                    restaurant.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TwText.textSm.copyWith(color: TwColors.textMuted),
                  ),
                ],
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
