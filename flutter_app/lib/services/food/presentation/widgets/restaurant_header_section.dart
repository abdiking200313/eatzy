import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../models/food_models.dart';
import '../../models/restaurant_menu.dart';

/// The restaurant name/description/item-count block that sits above the
/// category chip bar on [RestaurantScreen]'s menu. Also surfaces the
/// restaurant's physical [RestaurantLocation]s, once [locationsFuture]
/// resolves, as a single "store a • store b" line.
class RestaurantHeaderSection extends StatelessWidget {
  const RestaurantHeaderSection({
    super.key,
    required this.menu,
    required this.locationsFuture,
  });

  final RestaurantMenu menu;
  final Future<List<RestaurantLocation>> locationsFuture;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TwSpacing.screenX,
            TwSpacing.x6,
            TwSpacing.screenX,
            TwSpacing.x5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(menu.restaurant.name, style: TwText.text2xl),
              if (menu.restaurant.description.trim().isNotEmpty) ...[
                const SizedBox(height: TwSpacing.x2),
                Text(menu.restaurant.description, style: TwText.textSm),
              ],
              const SizedBox(height: TwSpacing.x3),
              Row(
                children: [
                  Icon(
                    Icons.restaurant_menu_rounded,
                    size: 18,
                    color: context.serviceColors.accent,
                  ),
                  const SizedBox(width: TwSpacing.x2),
                  Text('${menu.itemCount} items', style: TwText.fontBoldSm),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: TwSpacing.x2),
                    child: Text(
                      '•',
                      style: TextStyle(color: TwColors.textMuted),
                    ),
                  ),
                  Text(
                    '${menu.categories.length} categories',
                    style: TwText.textSm,
                  ),
                ],
              ),
              FutureBuilder<List<RestaurantLocation>>(
                future: locationsFuture,
                builder: (context, snapshot) {
                  final locations =
                      snapshot.data ?? const <RestaurantLocation>[];
                  if (locations.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: TwSpacing.x3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 18,
                          color: context.serviceColors.accent,
                        ),
                        const SizedBox(width: TwSpacing.x2),
                        Expanded(
                          child: Text(
                            locations
                                .map((location) => location.storeName)
                                .join(' • '),
                            style: TwText.textSm,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
