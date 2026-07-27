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
    final palette = context.serviceColors;
    return OutlinedCard(
      backgroundColor: palette.card,
      borderColor: palette.border,
      borderRadius: 18,
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
                  const SizedBox(height: TwSpacing.x3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppMoney.format(item.price),
                          style: TwText.fontBoldBase().copyWith(
                            color: palette.accent,
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

    return trimmedUrl.isEmpty
        ? const _MenuImageFallback()
        : CachedNetworkImage(
            imageUrl: trimmedUrl,
            fit: BoxFit.cover,
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
