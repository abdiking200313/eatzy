import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme.dart';
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
    return OutlinedCard(
      backgroundColor: Colors.white,
      borderColor: TwColors.border,
      borderRadius: 18,
      padding: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 112, child: _MenuItemImage(imageUrl: item.imageUrl)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(TwSpacing.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TwText.fontBoldBase(),
                  ),
                  if (item.description.trim().isNotEmpty) ...[
                    const SizedBox(height: TwSpacing.x1),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TwText.textSm(),
                    ),
                  ],
                  const SizedBox(height: TwSpacing.x3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          NumberFormat.currency(
                            symbol: r'$',
                            decimalDigits: 2,
                          ).format(item.price),
                          style: TwText.fontBoldBase().copyWith(
                            color: TwColors.primary,
                          ),
                        ),
                      ),
                      SizedBox.square(
                        dimension: 36,
                        child: IconButton.filled(
                          key: ValueKey('add-to-cart-${item.id}'),
                          tooltip: 'Add ${item.name} to cart',
                          padding: EdgeInsets.zero,
                          onPressed: onAddToCart,
                          icon: const Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 19,
                          ),
                        ),
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
    return ColoredBox(
      color: TwColors.primarySoft,
      child: Center(
        child: showLoader
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(
                Icons.lunch_dining_rounded,
                color: TwColors.primary,
                size: 34,
              ),
      ),
    );
  }
}
