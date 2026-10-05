import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/store_hero_app_bar.dart';
import '../../models/food_models.dart';
import '../../models/restaurant_menu.dart';
import 'category_header_delegate.dart';
import 'menu_item_card.dart';
import 'restaurant_header_section.dart';
import 'restaurant_status_views.dart';

/// The scrollable body of `RestaurantScreen` once its menu has loaded: the
/// photo hero, [RestaurantHeaderSection], the pinned [CategoryHeaderDelegate]
/// chip bar, and each category's items.
///
/// [sectionKeyFor] supplies the same [GlobalKey] for a given category every
/// rebuild — `RestaurantScreen._syncSelectedCategoryFromScroll` reads each
/// key's `currentContext` to tell which category is currently in view, and
/// [onCategorySelected] (from tapping a chip) scrolls to that key's context.
class RestaurantMenuView extends StatelessWidget {
  const RestaurantMenuView({
    super.key,
    required this.menu,
    required this.locationsFuture,
    required this.selectedCategoryId,
    required this.scrollController,
    required this.sectionKeyFor,
    required this.onCategorySelected,
    required this.onAddToCart,
  });

  final RestaurantMenu menu;
  final Future<List<RestaurantLocation>> locationsFuture;
  final String? selectedCategoryId;
  final ScrollController scrollController;
  final GlobalKey Function(String categoryId) sectionKeyFor;
  final ValueChanged<MenuCategory> onCategorySelected;
  final void Function(MenuItem item, int quantity) onAddToCart;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        StoreHeroAppBar(
          title: menu.restaurant.name,
          imageUrl: menu.restaurant.logoUrl,
          fallbackIcon: Icons.restaurant_rounded,
          imageFit: BoxFit.contain,
        ),
        SliverToBoxAdapter(
          child: RestaurantHeaderSection(
            menu: menu,
            locationsFuture: locationsFuture,
          ),
        ),
        if (menu.categories.isNotEmpty)
          SliverPersistentHeader(
            pinned: true,
            delegate: CategoryHeaderDelegate(
              categories: menu.categories,
              selectedCategoryId:
                  selectedCategoryId ?? menu.categories.first.id,
              onSelected: onCategorySelected,
            ),
          ),
        if (menu.categories.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyMenuView(),
          )
        else
          for (final category in menu.categories) ...[
            SliverToBoxAdapter(
              child: MenuCategorySectionHeader(
                category: category,
                sectionKey: sectionKeyFor(category.id),
              ),
            ),
            // A per-category `SliverList.builder` (rather than the whole
            // category folded into one eager `SliverToBoxAdapter`+`Column`)
            // so item cards — and the `CachedNetworkImage` requests they
            // kick off — are only built once they scroll into view. The
            // header above stays an eager `SliverToBoxAdapter` so its
            // `GlobalKey` context is always mounted for the category-chip
            // "jump to section" scroll (`Scrollable.ensureVisible`).
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = category.items[index];
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        TwSpacing.screenX,
                        0,
                        TwSpacing.screenX,
                        index == category.items.length - 1 ? 0 : TwSpacing.x3,
                      ),
                      child: MenuItemCard(
                        restaurantId: menu.restaurant.id,
                        item: item,
                        onAddToCart: (quantity) => onAddToCart(item, quantity),
                      ),
                    ),
                  ),
                );
              }, childCount: category.items.length),
            ),
          ],
        const SliverToBoxAdapter(child: SizedBox(height: TwSpacing.x6)),
      ],
    );
  }
}

/// A category's name/item-count heading within [RestaurantMenuView].
///
/// [sectionKey] is set directly on the inner [Row] (matching this file's
/// pre-extraction layout exactly) rather than on this widget, because
/// `RestaurantScreen._syncSelectedCategoryFromScroll` reads each key's
/// `currentContext.findRenderObject()` to find that row's on-screen top —
/// putting the key on an outer wrapper would resolve to a different
/// render object (and a different vertical offset) and desync scrolling.
class MenuCategorySectionHeader extends StatelessWidget {
  const MenuCategorySectionHeader({
    super.key,
    required this.category,
    required this.sectionKey,
  });

  final MenuCategory category;
  final GlobalKey sectionKey;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TwSpacing.screenX,
            TwSpacing.sectionGap,
            TwSpacing.screenX,
            TwSpacing.headerToContent,
          ),
          child: Row(
            key: sectionKey,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text(category.name, style: TwText.sectionTitle)),
              Text(
                '${category.items.length} '
                '${category.items.length == 1 ? 'item' : 'items'}',
                style: TwText.textXs.copyWith(color: TwColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
