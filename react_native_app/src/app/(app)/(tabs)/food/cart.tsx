/**
 * Ports flutter_app/lib/services/food/presentation/food_cart_screen.dart's
 * `CartScreen` (issue #386): the food cart, rendered through the shared
 * `CartView` (issue #379) against the app-wide `useFoodCartStore` (issue
 * #376) and its live `useFoodCartTotals` (subtotal, tax, delivery fee,
 * total -- tax/delivery fee show "Calculated at checkout" until
 * `service_pricing` has loaded, exactly like the Dart `CheckoutLine.pending`).
 *
 * Quantity rules mirror the Dart screen: decrease is disabled at 1 (use
 * remove instead), increase is disabled at `FOOD_CART_MAXIMUM_QUANTITY`.
 *
 * `_runMutation`'s "could not be saved" snack bar is kept for parity, shown
 * through this screen's own `useCartSnackbar` (there is no app-wide snack
 * bar host yet -- see that hook's doc comment). In practice the RN store's
 * `CartWriteQueue` already logs and swallows persistence failures, so this
 * only fires if a store action itself rejects.
 */
import { router } from 'expo-router';
import { useCallback } from 'react';
import { View } from 'react-native';

import { CartSnackbar } from '@/components/cart-snackbar';
import { CartView, type CartLine } from '@/components/cart-view';
import { checkoutLine, pendingCheckoutLine } from '@/components/checkout-view';
import { useCartSnackbar } from '@/hooks/use-cart-snackbar';
import { AppRoutes } from '@/platform/navigation/app-routes';
import {
  cartItemTotal,
  FOOD_CART_MAXIMUM_QUANTITY,
  useFoodCartStore,
  useFoodCartTotals,
} from '@/stores/food-cart-store';

const SAVE_FAILED_MESSAGE = 'The cart changed, but it could not be saved for next time.';

export default function FoodCartScreen() {
  const items = useFoodCartStore((state) => state.items);
  const isLoading = useFoodCartStore((state) => state.isLoading);
  const increment = useFoodCartStore((state) => state.increment);
  const decrement = useFoodCartStore((state) => state.decrement);
  const remove = useFoodCartStore((state) => state.remove);
  const clear = useFoodCartStore((state) => state.clear);
  const totals = useFoodCartTotals();
  const snackbar = useCartSnackbar();

  const showSnackbar = snackbar.show;
  const mutate = useCallback(
    (mutation: () => Promise<void>) => {
      mutation().catch(() => showSnackbar(SAVE_FAILED_MESSAGE));
    },
    [showSnackbar],
  );

  const lines: CartLine[] = items.map((item) => ({
    id: item.menuItemId,
    name: item.name,
    total: cartItemTotal(item),
    unitPrice: item.unitPrice,
    quantityLabel: `${item.quantity}`,
    imageUrl: item.imageUrl,
    onDecrease: item.quantity === 1 ? null : () => mutate(() => decrement(item.menuItemId)),
    onIncrease:
      item.quantity === FOOD_CART_MAXIMUM_QUANTITY ? null : () => mutate(() => increment(item.menuItemId)),
    onRemove: () => mutate(() => remove(item.menuItemId)),
  }));

  return (
    <View style={{ flex: 1 }}>
      <CartView
        showBackButton={false}
        isLoading={isLoading}
        isEmpty={items.length === 0}
        emptyMessage="Your cart is empty"
        browseLabel="Browse restaurants"
        // `router.replace` mirrors the Dart `context.go(AppRoutes.food)`.
        onBrowse={() => router.replace(AppRoutes.food as never)}
        storeName={totals.restaurantName ?? undefined}
        fallbackIcon="lunch-dining"
        service="food"
        lines={lines}
        feeLines={[
          checkoutLine('Subtotal', totals.subtotal),
          totals.tax == null ? pendingCheckoutLine('Tax') : checkoutLine('Tax', totals.tax),
          totals.deliveryFee == null
            ? pendingCheckoutLine('Delivery fee')
            : checkoutLine('Delivery fee', totals.deliveryFee),
        ]}
        total={totals.total}
        // `router.push` mirrors the Dart `context.push(AppRoutes.foodCheckout)`.
        onCheckout={() => router.push(AppRoutes.foodCheckout as never)}
        onClear={() => mutate(clear)}
      />
      <CartSnackbar message={snackbar.message} />
    </View>
  );
}
