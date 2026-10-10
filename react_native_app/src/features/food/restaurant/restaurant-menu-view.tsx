/**
 * Ports `flutter_app/lib/services/food/presentation/widgets/restaurant_menu_view.dart`'s
 * `RestaurantMenuView` + `MenuCategorySectionHeader` (issue #383): the
 * scrollable body of the restaurant screen once its menu has loaded -- the
 * photo hero, the restaurant header, the sticky category chip bar, then
 * each category's heading and item cards.
 *
 * Flutter builds this as a `CustomScrollView` of slivers (one lazy
 * `SliverList` per category). This port flattens the same content into one
 * row list rendered by FlashList, so long menus stay virtualized; the chip
 * bar row is pinned with `stickyHeaderIndices`. The selected-chip sync on
 * scroll (Dart's `_syncSelectedCategoryFromScroll` reading each section
 * heading's on-screen offset) is approximated with
 * `onViewableItemsChanged`: the category of the topmost mostly-visible menu
 * row is treated as "current".
 */
import { FlashList, type FlashListRef, type ViewToken } from '@shopify/flash-list';
import { useCallback, useMemo, useRef, type ReactNode } from 'react';
import { Text, View } from 'react-native';

import { StoreHeroAppBar } from '@/components/store-hero-app-bar';
import type { RestaurantLocation } from '@/features/food/api/restaurant-location';
import type { MenuCategory, MenuItem, RestaurantMenu } from '@/features/food/api/restaurant-menu';
import { spacing } from '@/theme/tokens';

import { CategoryChipBar, CATEGORY_CHIP_BAR_HEIGHT } from './category-chip-bar';
import { MenuItemCard } from './menu-item-card';
import { RESTAURANT_CONTENT_MAX_WIDTH, RestaurantHeaderSection } from './restaurant-header-section';
import { EmptyMenuView } from './restaurant-status-views';

export type RestaurantMenuRow =
  | { kind: 'hero'; key: 'hero' }
  | { kind: 'header'; key: 'header' }
  | { kind: 'chips'; key: 'chips' }
  | { kind: 'empty'; key: 'empty' }
  | { kind: 'section'; key: string; category: MenuCategory }
  | { kind: 'item'; key: string; categoryId: string; item: MenuItem; isLast: boolean }
  | { kind: 'footer'; key: 'footer' };

/**
 * Flattens `menu` into list rows, in the same order as the Dart slivers:
 * hero, header, chip bar (only when there are categories), then either the
 * empty view or each category's heading + items, then bottom spacing.
 */
export function buildRestaurantMenuRows(menu: RestaurantMenu): RestaurantMenuRow[] {
  const rows: RestaurantMenuRow[] = [
    { kind: 'hero', key: 'hero' },
    { kind: 'header', key: 'header' },
  ];
  if (menu.categories.length === 0) {
    rows.push({ kind: 'empty', key: 'empty' });
  } else {
    rows.push({ kind: 'chips', key: 'chips' });
    for (const category of menu.categories) {
      rows.push({ kind: 'section', key: `section-${category.id}`, category });
      category.items.forEach((item, index) => {
        rows.push({
          kind: 'item',
          key: `item-${category.id}-${item.id}`,
          categoryId: category.id,
          item,
          isLast: index === category.items.length - 1,
        });
      });
    }
  }
  rows.push({ kind: 'footer', key: 'footer' });
  return rows;
}

/** The index of the chip bar row in {@link buildRestaurantMenuRows}'s output (after hero + header). */
export const CHIP_BAR_ROW_INDEX = 2;

function rowCategoryId(row: RestaurantMenuRow): string | null {
  if (row.kind === 'section') return row.category.id;
  if (row.kind === 'item') return row.categoryId;
  return null;
}

export type RestaurantMenuViewProps = {
  menu: RestaurantMenu;
  locations: RestaurantLocation[] | undefined;
  selectedCategoryId: string | null;
  topInset: number;
  onBackPress: () => void;
  /** Called with the category whose chip was tapped; the view scrolls to it itself. */
  onCategorySelected: (category: MenuCategory) => void;
  /** Called as the menu scrolls, with the category currently in view. */
  onCategoryInView: (categoryId: string) => void;
  onItemPress: (item: MenuItem) => void;
  onAddToCart: (item: MenuItem, quantity: number) => void;
};

export function RestaurantMenuView({
  menu,
  locations,
  selectedCategoryId,
  topInset,
  onBackPress,
  onCategorySelected,
  onCategoryInView,
  onItemPress,
  onAddToCart,
}: RestaurantMenuViewProps) {
  const rows = useMemo(() => buildRestaurantMenuRows(menu), [menu]);
  const listRef = useRef<FlashListRef<RestaurantMenuRow>>(null);
  const effectiveSelectedId = selectedCategoryId ?? menu.categories[0]?.id ?? '';

  const selectCategory = useCallback(
    (category: MenuCategory) => {
      onCategorySelected(category);
      const index = rows.findIndex((row) => row.kind === 'section' && row.category.id === category.id);
      if (index >= 0) {
        void listRef.current?.scrollToIndex({ index, animated: true, viewOffset: CATEGORY_CHIP_BAR_HEIGHT + topInset });
      }
    },
    [onCategorySelected, rows, topInset],
  );

  const onViewableItemsChanged = useCallback(
    ({ viewableItems }: { viewableItems: ViewToken<RestaurantMenuRow>[] }) => {
      for (const token of viewableItems) {
        const categoryId = token.item ? rowCategoryId(token.item) : null;
        if (categoryId) {
          onCategoryInView(categoryId);
          return;
        }
      }
    },
    [onCategoryInView],
  );

  return (
    <FlashList
      ref={listRef}
      testID="restaurant-menu-list"
      data={rows}
      keyExtractor={(row) => row.key}
      getItemType={(row) => row.kind}
      extraData={effectiveSelectedId}
      stickyHeaderIndices={menu.categories.length > 0 ? [CHIP_BAR_ROW_INDEX] : undefined}
      viewabilityConfig={{ itemVisiblePercentThreshold: 50 }}
      onViewableItemsChanged={onViewableItemsChanged}
      renderItem={({ item: row, target }) => {
        switch (row.kind) {
          case 'hero':
            return (
              <StoreHeroAppBar
                title={menu.restaurant.name}
                imageUrl={menu.restaurant.logoUrl}
                fallbackIcon="restaurant"
                imageFit="contain"
                showBackButton
                onBackPress={onBackPress}
                service="food"
              />
            );
          case 'header':
            return <RestaurantHeaderSection menu={menu} locations={locations} />;
          case 'chips': {
            const isSticky = target === 'StickyHeader';
            return (
              <CategoryChipBar
                categories={menu.categories}
                selectedCategoryId={effectiveSelectedId}
                onSelected={selectCategory}
                topInset={isSticky ? topInset : 0}
                elevated={isSticky}
              />
            );
          }
          case 'empty':
            return <EmptyMenuView />;
          case 'section':
            return <MenuCategorySectionHeader category={row.category} />;
          case 'item':
            return (
              <ContentColumn style={{ paddingBottom: row.isLast ? 0 : spacing.x3 }}>
                <MenuItemCard
                  item={row.item}
                  onPress={() => onItemPress(row.item)}
                  onAddToCart={(quantity) => onAddToCart(row.item, quantity)}
                />
              </ContentColumn>
            );
          case 'footer':
            // Leaves room under the last item for the floating "View cart" button.
            return <View style={{ height: spacing.x6 + 72 }} />;
        }
      }}
    />
  );
}

function ContentColumn({ children, style }: { children: ReactNode; style?: object }) {
  return (
    <View className="items-center">
      <View style={[{ width: '100%', maxWidth: RESTAURANT_CONTENT_MAX_WIDTH, paddingHorizontal: spacing.screenX }, style]}>
        {children}
      </View>
    </View>
  );
}

/** Ports `MenuCategorySectionHeader`: a category's name and item count. */
export function MenuCategorySectionHeader({ category }: { category: MenuCategory }) {
  const count = category.items.length;
  return (
    <ContentColumn style={{ paddingTop: spacing.sectionGap, paddingBottom: spacing.headerToContent }}>
      <View testID={`menu-section-${category.id}`} className="flex-row items-baseline">
        <Text className="flex-1 text-sectionTitle font-outfitSemiBold text-text">{category.name}</Text>
        <Text className="text-textXs font-outfitMedium text-textMuted">{`${count} ${count === 1 ? 'item' : 'items'}`}</Text>
      </View>
    </ContentColumn>
  );
}
