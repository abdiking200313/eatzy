import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../widgets/app_cards.dart';
import 'widgets/onboarding_page.dart';

/// Screen 1 of the redesigned onboarding flow (issue #233): "See What's
/// Open Near You" — a distance chip above a short list of nearby
/// restaurants. Sample/placeholder content for the mockup, not real data.
class OnboardingPage1 extends StatelessWidget {
  const OnboardingPage1({super.key});

  static const List<_Restaurant> _restaurants = [
    _Restaurant(
      name: 'Ayam Penyet Ria',
      etaMinutes: '20 min',
      cuisine: 'Malaysian',
      distanceKm: '0.4 km',
      rating: '4.8',
    ),
    _Restaurant(
      name: 'Tokyo Ramen Bar',
      etaMinutes: '28 min',
      cuisine: 'Japanese',
      distanceKm: '0.9 km',
      rating: '4.6',
    ),
    _Restaurant(
      name: 'Bangkok Wok',
      etaMinutes: '32 min',
      cuisine: 'Thai',
      distanceKm: '1.2 km',
      rating: '4.5',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return OnboardingPage(
      title: "See What's Open Near You",
      description:
          'Browse the kitchens around your address, sorted by how fast '
          'they deliver.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(alignment: Alignment.centerLeft, child: _DistanceChip()),
          const SizedBox(height: TwSpacing.x5),
          for (var i = 0; i < _restaurants.length; i++) ...[
            if (i > 0) const SizedBox(height: TwSpacing.x3),
            _RestaurantCard(restaurant: _restaurants[i]),
          ],
        ],
      ),
    );
  }
}

class _DistanceChip extends StatelessWidget {
  const _DistanceChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TwSpacing.x4,
        vertical: TwSpacing.x2,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TwRadius.full),
        border: Border.all(color: TwColors.border),
        color: TwColors.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: TwColors.primary, width: 1.5),
            ),
            child: const Icon(Icons.radar, size: 12, color: TwColors.primary),
          ),
          const SizedBox(width: TwSpacing.x2),
          Flexible(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: TwText.textSm.copyWith(color: TwColors.text),
                children: [
                  const TextSpan(text: 'Within '),
                  TextSpan(text: '1.5 km', style: TwText.fontBoldSm),
                  const TextSpan(text: ' of you'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({required this.restaurant});

  final _Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      padding: const EdgeInsets.symmetric(
        horizontal: TwSpacing.x4,
        vertical: TwSpacing.x3,
      ),
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
                  style: TwText.fontBoldBase,
                ),
              ),
              const SizedBox(width: TwSpacing.x2),
              Text(
                restaurant.etaMinutes,
                style: TwText.fontBoldSm.copyWith(color: TwColors.primary),
              ),
            ],
          ),
          const SizedBox(height: TwSpacing.rhythmTight),
          Text(
            '${restaurant.cuisine} · ${restaurant.distanceKm} · '
            '${restaurant.rating}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TwText.textSm,
          ),
        ],
      ),
    );
  }
}

class _Restaurant {
  const _Restaurant({
    required this.name,
    required this.etaMinutes,
    required this.cuisine,
    required this.distanceKm,
    required this.rating,
  });

  final String name;
  final String etaMinutes;
  final String cuisine;
  final String distanceKm;
  final String rating;
}
