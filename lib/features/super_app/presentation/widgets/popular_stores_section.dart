import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme.dart';
import '../../../../platform/discovery/store_listing.dart';
import '../../../../widgets/app_cards.dart';

class PopularStoresSection extends StatelessWidget {
  const PopularStoresSection({
    super.key,
    required this.stream,
    required this.onRetry,
    this.initialData,
  });

  final Stream<List<StoreListing>> stream;
  final VoidCallback onRetry;
  final List<StoreListing>? initialData;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StoreListing>>(
      stream: stream,
      initialData: initialData,
      builder: (context, snapshot) {
        // Cached stores count as data even while a refresh is in flight, so
        // the spinner only shows when there is nothing cached at all.
        if (!snapshot.hasData && !snapshot.hasError) {
          return const SizedBox(
            height: 204,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final stores = snapshot.data ?? const <StoreListing>[];
        // An error with nothing cached to fall back on (every vertical
        // failed, see `StoreListingRepository`/issue #286) gets an error
        // state with retry, matching `_FoodHomeError`/`_StoreListError`.
        // A genuinely empty, non-error result just hides the section.
        if (snapshot.hasError) {
          return _PopularStoresError(onRetry: onRetry);
        }
        if (stores.isEmpty) {
          return const SizedBox.shrink();
        }
        // No fixed height: the row takes its tallest card's height, so the
        // cards grow with the text scale instead of overflowing.
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: TwSpacing.screenX),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: TwSpacing.carouselGap,
            children: [
              for (final store in stores.take(6))
                SizedBox(
                  width: 212,
                  child: StoreListCard(
                    name: store.name,
                    subtitle: store.subtitle,
                    imageUrl: store.imageUrl,
                    accentColor: ServiceThemes.forId(store.serviceId).accent,
                    onTap: () => context.push(store.route),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Mirrors `_FoodHomeError`/`_StoreListError`'s card+retry shape, but with a
/// neutral accent rather than a service-specific one, since this section
/// mixes stores from every vertical.
class _PopularStoresError extends StatelessWidget {
  const _PopularStoresError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TwSpacing.screenX),
      child: OutlinedCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: TwColors.primary),
            const SizedBox(height: TwSpacing.x2),
            const Text('Popular stores could not be loaded.'),
            const SizedBox(height: TwSpacing.x4),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
