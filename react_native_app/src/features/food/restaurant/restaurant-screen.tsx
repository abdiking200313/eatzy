/**
 * Ports `flutter_app/lib/services/food/presentation/restaurant_screen.dart`'s
 * `RestaurantScreen` (issue #383): one restaurant's menu, browsable by
 * category, with add-to-cart (including the "Start a new cart?" restaurant
 * conflict prompt), a short-lived confirmation snackbar, and the floating
 * "View cart" button.
 *
 * Differences from the Dart source, all forced by platform/stack:
 * - Data comes from `useRestaurantMenu`/`useRestaurantLocations` (TanStack
 *   Query) instead of `CatalogQueries.restaurantMenu`'s stream + a
 *   `Future`. Cached data still wins over the loading view and a failed
 *   background refresh; the error view only shows when nothing was cached.
 * - The cart is the app-wide `useFoodCartStore` (no injected
 *   `CartController`); tests reset the store's state instead.
 * - The conflict prompt is a native `Alert` instead of a Material
 *   `AlertDialog`, with the same title, copy, and button labels.
 */
import { router } from 'expo-router';
import { useCallback, useContext, useState } from 'react';
import { Alert, View } from 'react-native';
import { SafeAreaInsetsContext } from 'react-native-safe-area-context';

import { CartSnackbar } from '@/components/cart-snackbar';
import type { MenuCategory, MenuItem, RestaurantMenu } from '@/features/food/api/restaurant-menu';
import { useRestaurantLocations, useRestaurantMenu } from '@/features/food/api/use-restaurant-menu';
import { useCartSnackbar } from '@/hooks/use-cart-snackbar';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { AppRoutes, foodMenuItemDetails } from '@/platform/navigation/app-routes';
import { selectFoodCartItemCount, useFoodCartStore, type CartAddResult, type CartItem } from '@/stores/food-cart-store';
import { spacing } from '@/theme/tokens';

import { RestaurantCartFab } from './restaurant-cart-fab';
import { RestaurantMenuView } from './restaurant-menu-view';
import { RestaurantErrorView, RestaurantLoadingView } from './restaurant-status-views';

export type RestaurantScreenProps = {
  restaurantId: string;
};

/** Asks whether to replace a cart from another restaurant -- resolves `true` only for "Start new cart". */
function confirmStartNewCart(currentRestaurantName: string | null, newRestaurantName: string): Promise<boolean> {
  return new Promise((resolve) => {
    Alert.alert(
      'Start a new cart?',
      `Your cart contains items from ${currentRestaurantName ?? 'another restaurant'}. ` +
        `Starting a cart from ${newRestaurantName} will remove them.`,
      [
        { text: 'Keep cart', style: 'cancel', onPress: () => resolve(false) },
        { text: 'Start new cart', onPress: () => resolve(true) },
      ],
      { cancelable: true, onDismiss: () => resolve(false) },
    );
  });
}

/** Mirrors the Dart `switch (result)` confirmation copy. */
export function addToCartMessage(result: CartAddResult, item: MenuItem, quantity: number): string {
  const itemLabel = quantity > 1 ? `${quantity}× ${item.name}` : item.name;
  switch (result) {
    case 'quantityIncreased':
      return `${itemLabel} quantity increased`;
    case 'replacedRestaurant':
      return `New cart started with ${itemLabel}`;
    case 'maximumReached':
      return `${item.name} is already at the maximum quantity`;
    default:
      return `${itemLabel} added to cart`;
  }
}

export function RestaurantScreen({ restaurantId }: RestaurantScreenProps) {
  const menuQuery = useRestaurantMenu(restaurantId);
  const locationsQuery = useRestaurantLocations(restaurantId);
  const cartItemCount = useFoodCartStore((state) => selectFoodCartItemCount(state.items));
  const snackbar = useCartSnackbar();
  const colors = useSemanticColors();
  const insets = useContext(SafeAreaInsetsContext);
  const [selectedCategoryId, setSelectedCategoryId] = useState<string | null>(null);

  const showSnackbar = snackbar.show;

  const addToCart = useCallback(
    async (menu: RestaurantMenu, menuItem: MenuItem, quantity: number) => {
      const store = useFoodCartStore.getState();
      const cartItem: CartItem = {
        menuItemId: menuItem.id,
        restaurantId: menu.restaurant.id,
        restaurantName: menu.restaurant.name,
        name: menuItem.name,
        unitPrice: menuItem.price,
        imageUrl: menuItem.imageUrl,
        quantity,
      };

      try {
        let result = await store.addItem(cartItem, { quantity });
        if (result === 'restaurantConflict') {
          const currentItems = useFoodCartStore.getState().items;
          const currentRestaurantName = currentItems.length > 0 ? currentItems[0].restaurantName : null;
          const replaceCart = await confirmStartNewCart(currentRestaurantName, menu.restaurant.name);
          if (!replaceCart) {
            return;
          }
          result = await useFoodCartStore.getState().addItem(cartItem, { replaceRestaurantCart: true, quantity });
        }
        showSnackbar(addToCartMessage(result, menuItem, quantity));
      } catch {
        showSnackbar('The item was added, but the cart could not be saved.');
      }
    },
    [showSnackbar],
  );

  const goBack = useCallback(() => {
    if (router.canGoBack()) {
      router.back();
      return;
    }
    router.replace(AppRoutes.mainApp as never);
  }, []);

  const selectCategory = useCallback((category: MenuCategory) => setSelectedCategoryId(category.id), []);

  const menu = menuQuery.data;
  if (!menu) {
    return menuQuery.isError ? <RestaurantErrorView onRetry={() => void menuQuery.refetch()} /> : <RestaurantLoadingView />;
  }

  return (
    <View style={{ backgroundColor: colors.bg }} className="flex-1">
      <RestaurantMenuView
        menu={menu}
        locations={locationsQuery.data}
        selectedCategoryId={selectedCategoryId}
        topInset={insets?.top ?? 0}
        onBackPress={goBack}
        onCategorySelected={selectCategory}
        onCategoryInView={setSelectedCategoryId}
        onItemPress={(item) => router.push(foodMenuItemDetails(menu.restaurant.id, item.id) as never)}
        onAddToCart={(item, quantity) => void addToCart(menu, item, quantity)}
      />
      <View
        pointerEvents="box-none"
        style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: (insets?.bottom ?? 0) + (cartItemCount > 0 ? 76 : 0) }}>
        <CartSnackbar message={snackbar.message} />
      </View>
      <View pointerEvents="box-none" style={{ position: 'absolute', right: spacing.x5, bottom: (insets?.bottom ?? 0) + spacing.x5 }}>
        <RestaurantCartFab itemCount={cartItemCount} onViewCart={() => router.push(AppRoutes.foodCart as never)} />
      </View>
    </View>
  );
}
