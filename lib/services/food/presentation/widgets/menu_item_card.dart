import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../platform/localization/app_money.dart';
import '../../../../widgets/add_to_cart_button.dart';
import '../../../../widgets/app_cards.dart';
import '../../models/restaurant_menu.dart';
import '../menu_item_details_screen.dart';

class MenuItemCard extends StatelessWidget {
  const MenuItemCard({
    super.key,
    required this.item,
    required this.onAddToCart,
  });

  final MenuItem item;

  /// Called with the quantity to add: `1` from the inline add button, or
  /// whatever was picked on [MenuItemDetailsScreen].
  final ValueChanged<int> onAddToCart;

  @override
  Widget build(BuildContext context) {
    // White card only — the per-service accent stays confined to the
    // fallback imagery, never the card fill or border.
    return OutlinedCard(
      backgroundColor: TwColors.card,
      borderColor: TwColors.border,
      borderRadius: TwRadius.card,
      padding: const EdgeInsets.all(TwSpacing.x3),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              MenuItemDetailsScreen(item: item, onAddToCart: onAddToCart),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(TwRadius.tile),
            child: SizedBox(
              width: 100,
              height: 100,
              child: _MenuItemImage(imageUrl: item.imageUrl),
            ),
          ),
          const SizedBox(width: TwSpacing.x3_5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.name, style: TwText.fontBoldBase),
                if (item.description.trim().isNotEmpty) ...[
                  const SizedBox(height: TwSpacing.x1),
                  Text(item.description, style: TwText.textSm),
                ],
                const SizedBox(height: TwSpacing.x3_5),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppMoney.formatCents(item.price),
                        style: TwText.fontBoldBase.copyWith(
                          color: TwColors.primary,
                        ),
                      ),
                    ),
                    AddToCartButton(
                      key: ValueKey('add-to-cart-${item.id}'),
                      tooltip: 'Add ${item.name} to cart',
                      onPressed: () => onAddToCart(1),
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

class _MenuItemImage extends StatelessWidget {
  const _MenuItemImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl.trim();

    // Decode at roughly the rendered 100x100 box scaled for device pixel
    // density. Capped at 3x since a wider cap buys no visible sharpness on
    // a thumbnail this small while still inflating decode memory.
    final cacheScale = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
    // Only the width is capped: capping both dimensions decodes to that
    // exact box and squashes any photo that isn't already square. Doubled so
    // a wide photo still decodes tall enough to cover-crop sharply.
    final cacheWidth = (100 * 2 * cacheScale).round();
    return trimmedUrl.isEmpty
        ? const _MenuImageFallback()
        : CachedNetworkImage(
            imageUrl: trimmedUrl,
            fit: BoxFit.cover,
            memCacheWidth: cacheWidth,
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
