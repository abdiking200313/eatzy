/**
 * Ports `flutter_app/lib/services/grocery/presentation/grocery_cart_screen.dart`'s
 * `GroceryCartScreen` (issue #392 / P7-04): the Grocery/Fresh Meat/
 * Electronics cart, rendered through the shared `CartView` (#379) against
 * the per-`storeType` cart store (#376) and its live totals (subtotal +
 * delivery fee; grocery charges no tax).
 *
 * Quantity rules mirror the Dart screen: decrease always steps down (to
 * removal at zero), and an increase that would exceed stock shows "No more
 * {name} is available." in the cart snack bar.
 *
 * `storeName`: Flutter reads it from the controller's in-memory catalog
 * (`null` until that store was loaded). RN has no shared catalog cache, so
 * this loads the cart's store once through `storeLoader` (the same
 * `fetchGroceryStore` the store screen uses) and shows no name until then
 * or if it fails.
 */
import { router } from 'expo-router';
import { useEffect, useState } from 'react';
import { View } from 'react-native';

import { CartSnackbar } from '@/components/cart-snackbar';
import { CartView, type CartLine } from '@/components/cart-view';
import { checkoutLine, pendingCheckoutLine } from '@/components/checkout-view';
import { useCartSnackbar } from '@/hooks/use-cart-snackbar';
import {
  groceryCartLineTotal,
  groceryCartStoreFor,
  groceryQuantityLabel,
  useGroceryCartTotals,
  type GroceryStoreType,
} from '@/stores/grocery-cart-store';

import { fetchGroceryStore } from './api/grocery-repository';
import type { GroceryStore } from './api/grocery-store';
import { GROCERY_STORE_TYPE_META } from './grocery-store-type-meta';

export type GroceryCartScreenProps = {
  /** Grocery, Fresh Meat and Electronics each have their own cart. */
  storeType?: GroceryStoreType;
  /** Test seam; defaults to `fetchGroceryStore`. */
  storeLoader?: (storeId: string) => Promise<GroceryStore | null>;
};

/** Loads the display name of the store the cart belongs to; `null` until known. */
export function useGroceryStoreName(
  storeId: string | null,
  storeLoader: (storeId: string) => Promise<GroceryStore | null>,
): string | null {
  const [loaded, setLoaded] = useState<{ storeId: string; name: string } | null>(null);

  useEffect(() => {
    if (storeId == null) return;
    let cancelled = false;
    storeLoader(storeId)
      .then((store) => {
        if (!cancelled && store != null) setLoaded({ storeId, name: store.name });
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, [storeId, storeLoader]);

  return loaded != null && loaded.storeId === storeId ? loaded.name : null;
}

export function GroceryCartScreen({ storeType = 'grocery', storeLoader = fetchGroceryStore }: GroceryCartScreenProps) {
  const meta = GROCERY_STORE_TYPE_META[storeType];
  const useStore = groceryCartStoreFor(storeType).store;
  const lines = useStore((state) => state.lines);
  const isLoading = useStore((state) => state.isLoading);
  const increment = useStore((state) => state.increment);
  const decrement = useStore((state) => state.decrement);
  const remove = useStore((state) => state.remove);
  const totals = useGroceryCartTotals(storeType);
  const storeName = useGroceryStoreName(totals.storeId, storeLoader);
  const snackbar = useCartSnackbar();

  const cartLines: CartLine[] = lines.map((line) => ({
    id: line.product.id,
    name: line.product.name,
    total: groceryCartLineTotal(line),
    unitPrice: line.product.unitPrice,
    quantityLabel: groceryQuantityLabel(line),
    imageUrl: line.product.imageUrl,
    onDecrease: () => decrement(line.product.id),
    onIncrease: () => {
      if (!increment(line.product.id)) {
        snackbar.show(`No more ${line.product.name} is available.`);
      }
    },
    onRemove: () => remove(line.product.id),
  }));

  return (
    <View style={{ flex: 1 }}>
      <CartView
        title={`${meta.serviceName} cart`}
        isLoading={isLoading}
        isEmpty={lines.length === 0}
        emptyMessage={`Your ${meta.serviceName.toLowerCase()} cart is empty`}
        browseLabel="Browse stores"
        // `router.replace` mirrors the Dart `context.go(storeType.listRoute)`.
        onBrowse={() => router.replace(meta.listRoute as never)}
        storeName={storeName ?? undefined}
        fallbackIcon="shopping-basket"
        service="grocery"
        slug={meta.slug}
        lines={cartLines}
        feeLines={[
          checkoutLine('Subtotal', totals.subtotal),
          totals.deliveryFee == null
            ? pendingCheckoutLine('Delivery fee')
            : checkoutLine('Delivery fee', totals.deliveryFee),
        ]}
        total={totals.total}
        // `router.push` mirrors the Dart `context.push(storeType.checkoutRoute)`.
        onCheckout={() => router.push(meta.checkoutRoute as never)}
      />
      <CartSnackbar message={snackbar.message} />
    </View>
  );
}
