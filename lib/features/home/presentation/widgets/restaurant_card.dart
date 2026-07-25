import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import '../../models/restaurant.dart';

class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onOrderPressed,
  });

  final Restaurant restaurant;
  final VoidCallback onOrderPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      backgroundColor: Colors.white,
      borderRadius: 16,
      borderColor: Colors.transparent,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _RestaurantImage(),
          Padding(
            padding: const EdgeInsets.all(TwSpacing.x5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  restaurant.name,
                  style: TwText.textXl(),
                ),
                const SizedBox(height: TwSpacing.x3),
                _RestaurantSummary(restaurant: restaurant),
                const SizedBox(height: TwSpacing.x4),
                _RestaurantOrderRow(
                  distance: restaurant.distance,
                  onOrderPressed: onOrderPressed,
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
  const _RestaurantImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: const BoxDecoration(
        color: TwColors.primaryAccent,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
    );
  }
}

class _RestaurantSummary extends StatelessWidget {
  const _RestaurantSummary({
    required this.restaurant,
  });

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.star_rounded,
          color: TwColors.blue400,
          size: 18,
        ),
        const SizedBox(width: TwSpacing.x1),
        Text(
          '${restaurant.rating} · ${restaurant.reviews}',
          style: TwText.textXs().copyWith(
            color: TwColors.textMuted,
          ),
        ),
        const Spacer(),
        Text(
          restaurant.price,
          style: TwText.fontBoldSm().copyWith(
            color: TwColors.primary,
          ),
        ),
      ],
    );
  }
}

class _RestaurantOrderRow extends StatelessWidget {
  const _RestaurantOrderRow({
    required this.distance,
    required this.onOrderPressed,
  });

  final String distance;
  final VoidCallback onOrderPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.location_on_outlined,
          color: TwColors.primary,
          size: 16,
        ),
        const SizedBox(width: TwSpacing.x1),
        Expanded(
          child: Text(
            distance,
            style: TwText.textXs().copyWith(
              color: TwColors.textMuted,
            ),
          ),
        ),
        PrimaryButton(
          label: 'Order',
          onPressed: onOrderPressed,
          fullWidth: false,
        ),
      ],
    );
  }
}
