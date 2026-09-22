import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../platform/localization/app_money.dart';
import '../../../widgets/app_cards.dart';
import '../models/restaurant_menu.dart';

/// A full-screen "more info" page for a single menu item, reached by
/// tapping its card in [RestaurantScreen] (not the card's own add-to-cart
/// button, which still adds instantly without navigating here). Not a
/// go_router route — like a bottom sheet or dialog, this is only ever
/// reached by a direct push from the one place that already holds the full
/// [MenuItem], so it doesn't need a shareable/deep-linkable URL.
class MenuItemDetailsScreen extends StatelessWidget {
  const MenuItemDetailsScreen({
    super.key,
    required this.item,
    required this.onAddToCart,
  });

  final MenuItem item;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 260,
            backgroundColor: TwColors.card,
            foregroundColor: TwColors.text,
            flexibleSpace: FlexibleSpaceBar(
              background: _ItemHero(imageUrl: item.imageUrl),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(TwSpacing.x5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: TwText.text2xl),
                  const SizedBox(height: TwSpacing.x2),
                  Text(
                    AppMoney.formatCents(item.price),
                    style: TwText.fontBoldBase.copyWith(color: palette.accent),
                  ),
                  if (item.description.trim().isNotEmpty) ...[
                    const SizedBox(height: TwSpacing.x4),
                    Text(item.description, style: TwText.textSm),
                  ],
                  const SizedBox(height: TwSpacing.x8),
                  PrimaryButton(
                    label: 'Add to cart',
                    icon: const Icon(
                      Icons.shopping_cart_outlined,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      onAddToCart();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemHero extends StatelessWidget {
  const _ItemHero({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl.trim();
    final cacheScale = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
    final cacheWidth = (MediaQuery.of(context).size.width * cacheScale).round();
    final cacheHeight = (260 * cacheScale).round();
    return ColoredBox(
      color: TwColors.card,
      child: trimmedUrl.isEmpty
          ? _ItemHeroFallback()
          : CachedNetworkImage(
              imageUrl: trimmedUrl,
              fit: BoxFit.cover,
              memCacheWidth: cacheWidth,
              memCacheHeight: cacheHeight,
              placeholder: (_, _) => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: (_, _, _) => _ItemHeroFallback(),
            ),
    );
  }
}

class _ItemHeroFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.lunch_dining_rounded,
        color: context.serviceColors.accent,
        size: 72,
      ),
    );
  }
}
