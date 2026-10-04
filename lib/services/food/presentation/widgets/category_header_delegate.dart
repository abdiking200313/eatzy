import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../models/restaurant_menu.dart';

/// Fixed height of the pinned category-chip bar (this delegate's
/// `minExtent`/`maxExtent`) — shared with `_RestaurantScreenState`'s
/// scroll-position math (`RestaurantScreen`) so the two stay in sync. Sized
/// for the sticky chip bar's 18-top/12-bottom padding plus a 36px chip.
const kCategoryHeaderExtent = 72.0;

/// The pinned, horizontally-scrolling category chip bar that sticks below
/// `StoreHeroAppBar` once the hero scrolls away. Selecting a chip jumps the
/// menu to that category's section (`RestaurantScreen._selectCategory`);
/// scrolling the menu itself updates [selectedCategoryId] back via
/// `RestaurantScreen._syncSelectedCategoryFromScroll`.
class CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  CategoryHeaderDelegate({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  final List<MenuCategory> categories;
  final String selectedCategoryId;
  final ValueChanged<MenuCategory> onSelected;

  @override
  double get minExtent => kCategoryHeaderExtent;

  @override
  double get maxExtent => kCategoryHeaderExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final palette = context.serviceColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.background,
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: TwColors.slate900.withOpacityValue(20 / 255),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              TwSpacing.screenX,
              18,
              TwSpacing.screenX,
              TwSpacing.x3,
            ),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: TwSpacing.x2),
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = category.id == selectedCategoryId;

              return ChoiceChip(
                showCheckmark: false,
                selected: isSelected,
                selectedColor: palette.accent,
                backgroundColor: palette.soft,
                side: BorderSide(
                  color: isSelected ? palette.accent : palette.border,
                ),
                label: Text(category.name),
                labelStyle: TwText.textXs.copyWith(
                  color: isSelected ? palette.onAccent : palette.accent,
                ),
                onSelected: (_) => onSelected(category),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant CategoryHeaderDelegate oldDelegate) =>
      oldDelegate.categories != categories ||
      oldDelegate.selectedCategoryId != selectedCategoryId;
}
