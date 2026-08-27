import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import '../../models/restaurant.dart';

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
    // White card only — the per-service accent stays confined to the
    // fallback imagery/icon chip, never the card fill or border.
    return OutlinedCard(
      backgroundColor: TwColors.card,
      borderRadius: TwRadius.xl,
      borderColor: TwColors.border,
      padding: EdgeInsets.zero,
      onTap: onPressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RestaurantImage(restaurant: restaurant),
          Padding(
            padding: const EdgeInsets.all(TwSpacing.x5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        restaurant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TwText.textXl,
                      ),
                    ),
                    // const SizedBox(width: TwSpacing.x2),
                    // _OpenBadge(isOpen: restaurant.isOpen),
                  ],
                ),

                const SizedBox(height: TwSpacing.x2),
                Text(
                  restaurant.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TwText.textSm.copyWith(color: TwColors.textMuted),
                ),

                const SizedBox(height: TwSpacing.rhythmTight),
                // A CTA link, not list-card body content — kept on the
                // neutral brand primary rather than the per-service accent,
                // which stays confined to the icon chip/fallback imagery.
                Row(
                  children: [
                    Text(
                      'View menu',
                      style: TwText.fontBoldSm.copyWith(
                        color: TwColors.primary,
                      ),
                    ),
                    const SizedBox(width: TwSpacing.x1),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: TwColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantImage extends StatelessWidget {
  const _RestaurantImage({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final logoUrl = restaurant.logoUrl.trim();
    return SizedBox(
      height: 180,
      width: double.infinity,
      child: logoUrl.isEmpty
          ? const _ImageFallback()
          : CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => const _ImageFallback(showLoader: true),
              errorWidget: (_, _, _) => const _ImageFallback(),
            ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({this.showLoader = false});

  final bool showLoader;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return ColoredBox(
      color: palette.soft,
      child: Center(
        child: showLoader
            ? const CircularProgressIndicator(strokeWidth: 2)
            : Icon(Icons.restaurant_rounded, color: palette.accent, size: 42),
      ),
    );
  }
}
