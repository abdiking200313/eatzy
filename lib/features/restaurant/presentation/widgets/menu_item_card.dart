import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../platform/localization/app_money.dart';
import '../../../../widgets/add_to_cart_button.dart';
import '../../../../widgets/app_cards.dart';
import '../../models/restaurant_menu.dart';

class MenuItemCard extends StatelessWidget {
  const MenuItemCard({
    super.key,
    required this.item,
    required this.onAddToCart,
  });

  final MenuItem item;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    // White card only — the per-service accent stays confined to the
    // fallback imagery, never the card fill or border.
    return OutlinedCard(
      backgroundColor: TwColors.card,
      borderColor: TwColors.border,
      borderRadius: TwRadius.xl,
      padding: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            height: 148,
            child: _MenuItemImage(imageUrl: item.imageUrl),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(TwSpacing.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item.name, style: TwText.fontBoldBase()),
                  if (item.description.trim().isNotEmpty) ...[
                    const SizedBox(height: TwSpacing.x1),
                    Text(item.description, style: TwText.textSm()),
                  ],
                  const SizedBox(height: TwSpacing.rhythmDefault),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppMoney.format(item.price),
                          style: TwText.fontBoldBase().copyWith(
                            color: TwColors.primary,
                          ),
                        ),
                      ),
                      AddToCartButton(
                        key: ValueKey('add-to-cart-${item.id}'),
                        tooltip: 'Add ${item.name} to cart',
                        onPressed: onAddToCart,
                      ),
                    ],
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

class _MenuItemImage extends StatelessWidget {
  const _MenuItemImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl.trim();

    // Decode at roughly the rendered 112x148 box scaled for device pixel
    // density. Capped at 3x since a wider cap buys no visible sharpness on
    // a thumbnail this small while still inflating decode memory.
    final cacheScale = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
    final cacheWidth = (112 * cacheScale).round();
    final cacheHeight = (148 * cacheScale).round();
    return trimmedUrl.isEmpty
        ? const _MenuImageFallback()
        : CachedNetworkImage(
            imageUrl: trimmedUrl,
            fit: BoxFit.cover,
            memCacheWidth: cacheWidth,
            memCacheHeight: cacheHeight,
            placeholder: (_, _) => const _MenuImageFallback(showLoader: true),
            errorWidget: (_, _, _) => const _MenuImageFallback(),
          );
  }
}

class _MenuImageFallback extends StatelessWidget {
  const _MenuImageFallback({this.showLoader = false});

  final bool showLoader;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return ColoredBox(
      color: palette.soft,
      child: Center(
        child: showLoader
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.lunch_dining_rounded, color: palette.accent, size: 34),
      ),
    );
  }
}
