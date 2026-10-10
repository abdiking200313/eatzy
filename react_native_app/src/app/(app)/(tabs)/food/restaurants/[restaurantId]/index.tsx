/**
 * Ports flutter_app/lib/services/food/presentation/restaurant_screen.dart's
 * `RestaurantScreen` (issue #383): a restaurant's hero photo/name/
 * description, its menu grouped by category, and a floating "View cart"
 * button.
 *
 * Data loading is the sibling data pass's work, consumed here as-is:
 * `useRestaurantMenu(restaurantId)` (mirrors `CatalogQueries.restaurantMenu`
 * -- shows a cached menu instantly, refreshes in the background). This
 * screen only owns menu presentation, category selection, and the
 * add-to-cart/restaurant-conflict flow -- see `restaurant_screen.dart`'s
 * own `_addToCart` for the Dart original.
 *
 * `RestaurantLocationRepository` (the "store a • store b" line on the Dart
 * header) has no RN port yet -- dropped here rather than guessed at (see
 * `RestaurantHeaderSection`'s own doc comment).
 *
 * `MenuItemCard`'s tap target opens `MenuItemDetailsScreen` (issue #384)
 * at `foodMenuItemDetails(restaurantId, itemId)`.
 */
import { FlashList, type FlashListRef, type ViewToken } from '@shopify/flash-list';
import { router, useLocalSearchParams } from 'expo-router';
import { useCallback, useMemo, useRef, useState } from 'react';
import { Alert, View } from 'react-native';

import { AppScaffold } from '@/components/app-scaffold';
import { CartAppBarAction } from '@/components/cart-app-bar-action';
import { CartSnackbar } from '@/components/cart-snackbar';
import { CategoryChipBar } from '@/components/category-chip-bar';
import { EmptyState } from '@/components/empty-state';
import { ErrorState } from '@/components/error-state';
import { LoadingState } from '@/components/loading-state';
import { MenuCategoryHeader } from '@/components/menu-category-header';
import { MenuItemCard } from '@/components/menu-item-card';
import { RestaurantCartFab } from '@/components/restaurant-cart-fab';
import { RestaurantHeaderSection } from '@/components/restaurant-header-section';
import { StoreHeroAppBar } from '@/components/store-hero-app-bar';
import { useRestaurantMenu } from '@/features/food/api/use-restaurant-menu';
import type { MenuCategory, MenuItem } from '@/features/food/api/restaurant-menu';
import { restaurantMenuItemCount } from '@/features/food/api/restaurant-menu';
import { useCartSnackbar } from '@/hooks/use-cart-snackbar';
import { AppRoutes, foodMenuItemDetails } from '@/platform/navigation/app-routes';
import {
  selectFoodCartItemCount,
  useFoodCartStore,
  type CartAddResult,
} from '@/stores/food-cart-store';
import { spacing } from '@/theme/tokens';

type MenuRow = { kind: 'categoryHeader'; category: MenuCategory } | { kind: 'item'; item: MenuItem };

/**
 * Hoisted to a stable module-level constant: FlashList (like the
 * `ScrollView` it wraps) does not support changing `viewabilityConfig`
 * across renders, so this must be the same object identity every time
 * rather than a fresh literal in JSX.
 */
const MENU_VIEWABILITY_CONFIG = { itemVisiblePercentThreshold: 0 };

/** Mirrors `_RestaurantScreenState._addToCart`'s per-result confirmation copy. */
function confirmationMessage(result: CartAddResult, itemName: string): string {
  switch (result) {
    case 'quantityIncreased':
      return `${itemName} quantity increased`;
    case 'replacedRestaurant':
      return `New cart started with ${itemName}`;
    case 'maximumReached':
      return `${itemName} is already at the maximum quantity`;
    default:
      return `${itemName} added to cart`;
  }
}

export default function RestaurantMenuScreen() {
  const { restaurantId } = useLocalSearchParams<{ restaurantId: string }>();
  const menuQuery = useRestaurantMenu(restaurantId);
  const menu = menuQuery.data;

  const listRef = useRef<FlashListRef<MenuRow>>(null);
  const [selectedCategoryId, setSelectedCategoryId] = useState<string | null>(null);
  const snackbar = useCartSnackbar();

  const cartItems = useFoodCartStore((state) => state.items);
  const addToCartStore = useFoodCartStore((state) => state.addItem);
  const cartItemCount = selectFoodCartItemCount(cartItems);
  const cartRestaurantName = cartItems[0]?.restaurantName ?? null;

  const rows = useMemo<MenuRow[]>(() => {
    if (!menu) {
      return [];
    }
    return menu.categories.flatMap((category) => [
      { kind: 'categoryHeader' as const, category },
      ...category.items.map((item) => ({ kind: 'item' as const, item })),
    ]);
  }, [menu]);

  const stickyHeaderIndices = useMemo(
    () => rows.reduce<number[]>((indices, row, index) => (row.kind === 'categoryHeader' ? [...indices, index] : indices), []),
    [rows],
  );

  const categoryIndexById = useMemo(() => {
    const map = new Map<string, number>();
    rows.forEach((row, index) => {
      if (row.kind === 'categoryHeader') {
        map.set(row.category.id, index);
      }
    });
    return map;
  }, [rows]);

  const effectiveSelectedCategoryId = selectedCategoryId ?? menu?.categories[0]?.id ?? null;

  const selectCategory = useCallback(
    (categoryId: string) => {
      setSelectedCategoryId(categoryId);
      const index = categoryIndexById.get(categoryId);
      if (index != null) {
        listRef.current?.scrollToIndex({ index, animated: true });
      }
    },
    [categoryIndexById],
  );

  // Keeps the chip bar's highlighted category synced to whichever
  // category header is currently pinned/visible at the top of the menu --
  // the FlashList-native substitute for `_syncSelectedCategoryFromScroll`'s
  // `RenderBox` offset math in the Dart source.
  const handleViewableItemsChanged = useCallback(({ viewableItems }: { viewableItems: ViewToken<MenuRow>[] }) => {
    const topHeader = viewableItems.find((token) => token.isViewable && token.item.kind === 'categoryHeader');
    if (topHeader && topHeader.item.kind === 'categoryHeader') {
      setSelectedCategoryId(topHeader.item.category.id);
    }
  }, []);

  const addToCart = useCallback(
    async (item: MenuItem) => {
      if (!menu) {
        return;
      }
      const cartItem = {
        menuItemId: item.id,
        restaurantId: menu.restaurant.id,
        restaurantName: menu.restaurant.name,
        name: item.name,
        unitPrice: item.price,
        imageUrl: item.imageUrl,
        quantity: 1,
      };

      const result = await addToCartStore(cartItem);

      if (result === 'restaurantConflict') {
        Alert.alert(
          'Start a new cart?',
          `Your cart contains items from ${cartRestaurantName ?? 'another restaurant'}. ` +
            `Starting a cart from ${menu.restaurant.name} will remove them.`,
          [
            { text: 'Keep cart', style: 'cancel' },
            {
              text: 'Start new cart',
              style: 'destructive',
              onPress: async () => {
                const replaceResult = await addToCartStore(cartItem, { replaceRestaurantCart: true });
                snackbar.show(confirmationMessage(replaceResult, item.name));
              },
            },
          ],
        );
        return;
      }

      snackbar.show(confirmationMessage(result, item.name));
    },
    [addToCartStore, cartRestaurantName, menu, snackbar],
  );

  // A cached menu (from a previous visit) wins over both the first-load
  // spinner and a failed background refresh -- mirrors the Dart
  // `StreamBuilder`'s `initialData`/`hasError` precedence (see
  // `useRestaurantMenu`'s own top comment on why this always revalidates).
  if (!menu) {
    return (
      <AppScaffold title="Restaurant" showBackButton>
        {menuQuery.isError ? (
          <ErrorState message="We could not load this menu." onRetry={() => menuQuery.refetch()} />
        ) : (
          <LoadingState message="Loading menu…" />
        )}
      </AppScaffold>
    );
  }

  const itemCount = restaurantMenuItemCount(menu);

  return (
    <View style={{ flex: 1 }}>
      <StoreHeroAppBar
        title={menu.restaurant.name}
        imageUrl={menu.restaurant.logoUrl}
        fallbackIcon="restaurant"
        imageFit="contain"
        showBackButton
        onBackPress={() => (router.canGoBack() ? router.back() : router.replace('/'))}
        service="food"
        actions={
          <CartAppBarAction
            itemCount={cartItemCount}
            tooltip={`Food cart (${cartItemCount})`}
            onPress={() => router.push(AppRoutes.foodCart as never)}
            service="food"
          />
        }
      />

      {menu.categories.length > 0 && (
        <CategoryChipBar
          categories={menu.categories}
          selectedCategoryId={effectiveSelectedCategoryId}
          onSelected={selectCategory}
        />
      )}

      <View style={{ flex: 1 }}>
        <FlashList
          ref={listRef}
          testID="restaurant-menu-list"
          data={rows}
          keyExtractor={(row) => (row.kind === 'categoryHeader' ? `category-${row.category.id}` : `item-${row.item.id}`)}
          getItemType={(row) => row.kind}
          stickyHeaderIndices={stickyHeaderIndices}
          viewabilityConfig={MENU_VIEWABILITY_CONFIG}
          onViewableItemsChanged={handleViewableItemsChanged}
          ListHeaderComponent={
            <RestaurantHeaderSection
              name={menu.restaurant.name}
              description={menu.restaurant.description}
              itemCount={itemCount}
              categoryCount={menu.categories.length}
            />
          }
          ListEmptyComponent={
            <EmptyState icon="menu-book" title="No menu items yet" message="This restaurant has not added any items." />
          }
          ListFooterComponent={<View style={{ height: spacing.x6 }} />}
          renderItem={({ item: row }) =>
            row.kind === 'categoryHeader' ? (
              <MenuCategoryHeader name={row.category.name} itemCount={row.category.items.length} />
            ) : (
              <View style={{ paddingHorizontal: spacing.screenX, paddingTop: spacing.x2 }}>
                <MenuItemCard
                  item={row.item}
                  onPress={() => router.push(foodMenuItemDetails(menu.restaurant.id, row.item.id) as never)}
                  onAddToCart={() => addToCart(row.item)}
                />
              </View>
            )
          }
        />
      </View>

      <View pointerEvents="box-none" style={{ position: 'absolute', bottom: spacing.x5, right: spacing.x5 }}>
        <RestaurantCartFab itemCount={cartItemCount} onPress={() => router.push(AppRoutes.foodCart as never)} />
      </View>

      <CartSnackbar message={snackbar.message} />
    </View>
  );
}
