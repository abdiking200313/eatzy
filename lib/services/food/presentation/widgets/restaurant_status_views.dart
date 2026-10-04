import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';

/// Shown on `RestaurantScreen` while the menu's first load is in flight and
/// nothing has been cached yet.
class RestaurantLoadingView extends StatelessWidget {
  const RestaurantLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Text('Restaurant'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: TwColors.text,
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: TwSpacing.x4),
                Text('Loading menu…', style: TwText.textSm),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown on `RestaurantScreen` when the menu failed to load and nothing was
/// cached to fall back to; [onRetry] re-triggers `RestaurantScreen._retry`.
class RestaurantErrorView extends StatelessWidget {
  const RestaurantErrorView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Text('Restaurant'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: TwColors.text,
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(TwSpacing.x5),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: OutlinedCard(
                  backgroundColor: TwColors.card,
                  borderColor: TwColors.border,
                  borderRadius: TwRadius.xl,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        color: palette.accent,
                        size: 42,
                      ),
                      const SizedBox(height: TwSpacing.x3),
                      Text('We could not load this menu', style: TwText.textXl),
                      const SizedBox(height: TwSpacing.x2),
                      Text(
                        'Check your connection and try again.',
                        textAlign: TextAlign.center,
                        style: TwText.textSm,
                      ),
                      const SizedBox(height: TwSpacing.x5),
                      TextButton(
                        onPressed: onRetry,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown in [RestaurantMenuView] when a loaded menu has no categories.
class EmptyMenuView extends StatelessWidget {
  const EmptyMenuView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TwSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 48,
              color: context.serviceColors.accent,
            ),
            const SizedBox(height: TwSpacing.x3),
            Text('No menu items yet', style: TwText.textXl),
            const SizedBox(height: TwSpacing.x2),
            Text(
              'This restaurant has not added any items.',
              textAlign: TextAlign.center,
              style: TwText.textSm,
            ),
          ],
        ),
      ),
    );
  }
}
