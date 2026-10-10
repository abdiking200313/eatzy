/**
 * Ports flutter_app/lib/services/food/presentation/menu_item_details_screen.dart's
 * `MenuItemDetailsScreen` (issue #384): the full-screen "more info" page for
 * one menu item, reached by tapping its card on the restaurant screen or via
 * a deep link to `/food/restaurants/:restaurantId/item/:itemId`.
 *
 * Like the Dart screen it only takes the two route ids and finds the item in
 * the same `useRestaurantMenu` cache the restaurant screen reads, so a tap
 * from the menu renders instantly and a cold deep link loads the menu first.
 * A thin wrapper around the shared `ProductDetailsView`.
 *
 * Deviation: the Dart screen confirms an add with `showCartSnackBar`, which
 * lives on the app-wide `ScaffoldMessenger` and so survives the page popping.
 * This app has no global snackbar host yet (see `useCartSnackbar`'s doc
 * comment), and `ProductDetailsView` navigates back before calling
 * `onAddToCart`, so a success confirmation is conveyed by the cart badge and
 * FAB on the restaurant screen underneath instead. The restaurant-conflict
 * dialog and the "could not be saved" error still show, as native alerts
 * (which are app-wide).
 */
import { MaterialIcons } from '@expo/vector-icons';
import { useLocalSearchParams } from 'expo-router';
import { useCallback } from 'react';
import { Alert } from 'react-native';

import { AppScaffold } from '@/components/app-scaffold';
import { EmptyState } from '@/components/empty-state';
import { ErrorState } from '@/components/error-state';
import { LoadingState } from '@/components/loading-state';
import { ProductDetailsView } from '@/components/product-details-view';
import type { MenuItem, RestaurantMenu } from '@/features/food/api/restaurant-menu';
import { useRestaurantMenu } from '@/features/food/api/use-restaurant-menu';
import { useServiceTheme } from '@/hooks/use-service-theme';
import { formatCents } from '@/platform/money/format';
import { FOOD_CART_MAXIMUM_QUANTITY, useFoodCartStore, type CartItem } from '@/stores/food-cart-store';

/** Mirrors `_MenuItemDetailsScreenState._findItem`. */
function findMenuItem(menu: RestaurantMenu, itemId: string): MenuItem | null {
  for (const category of menu.categories) {
    const item = category.items.find((candidate) => candidate.id === itemId);
    if (item) {
      return item;
    }
  }
  return null;
}

const SAVE_FAILED_MESSAGE = 'The item was added, but the cart could not be saved.';

export default function MenuItemDetailsScreen() {
  const { restaurantId = '', itemId = '' } = useLocalSearchParams<{ restaurantId: string; itemId: string }>();
  const menuQuery = useRestaurantMenu(restaurantId);
  const menu = menuQuery.data;
  const palette = useServiceTheme('food');
  const addToCartStore = useFoodCartStore((state) => state.addItem);

  /** Mirrors `_MenuItemDetailsScreenState._addToCart`, including the cart-conflict dialog. */
  const addToCart = useCallback(
    async (currentMenu: RestaurantMenu, item: MenuItem, quantity: number) => {
      const cartItem: CartItem = {
        menuItemId: item.id,
        restaurantId: currentMenu.restaurant.id,
        restaurantName: currentMenu.restaurant.name,
        name: item.name,
        unitPrice: item.price,
        imageUrl: item.imageUrl,
        quantity: 1,
      };
      try {
        const result = await addToCartStore(cartItem, { quantity });
        if (result !== 'restaurantConflict') {
          return;
        }
        const cartRestaurantName = useFoodCartStore.getState().items[0]?.restaurantName;
        Alert.alert(
          'Start a new cart?',
          `Your cart contains items from ${cartRestaurantName ?? 'another restaurant'}. ` +
            `Starting a cart from ${currentMenu.restaurant.name} will remove them.`,
          [
            { text: 'Keep cart', style: 'cancel' },
            {
              text: 'Start new cart',
              style: 'destructive',
              onPress: () => {
                addToCartStore(cartItem, { quantity, replaceRestaurantCart: true }).catch(() =>
                  Alert.alert(SAVE_FAILED_MESSAGE),
                );
              },
            },
          ],
        );
      } catch {
        Alert.alert(SAVE_FAILED_MESSAGE);
      }
    },
    [addToCartStore],
  );

  if (!menu) {
    return (
      <AppScaffold title="Item" showBackButton>
        {menuQuery.isError ? (
          <ErrorState message="This item could not be loaded." onRetry={() => menuQuery.refetch()} />
        ) : (
          <LoadingState />
        )}
      </AppScaffold>
    );
  }

  const item = findMenuItem(menu, itemId);
  if (!item) {
    return (
      <AppScaffold title="Item" showBackButton>
        <EmptyState icon="no-meals" title="Item unavailable" message="This item is no longer available." />
      </AppScaffold>
    );
  }

  return (
    <ProductDetailsView
      imageUrl={item.imageUrl}
      fallback={<MaterialIcons name="lunch-dining" size={96} color={palette.accent} />}
      name={item.name}
      priceLabel={formatCents(item.price)}
      description={item.description}
      maxSteps={FOOD_CART_MAXIMUM_QUANTITY}
      quantityLabel={(steps) => `${steps}`}
      onAddToCart={(quantity) => void addToCart(menu, item, quantity)}
      service="food"
    />
  );
}
