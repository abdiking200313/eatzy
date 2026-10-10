/**
 * Ports `flutter_app/lib/services/pharmacy/presentation/pharmacy_cart_screen.dart`'s
 * `PharmacyCartScreen` (issue #395 / P7-07): the pharmacy cart, rendered
 * through the shared `CartView` (#379) against the pharmacy cart store
 * (#376) and its live totals (subtotal + delivery fee; pharmacy charges no
 * tax).
 *
 * Quantity rules mirror the Dart screen: decrease always steps down (to
 * removal at zero), increase is disabled once a line reaches its stock, and
 * a "Clear" action (with confirmation) empties the cart. Unlike grocery,
 * Flutter shows no store name here, so neither does this port.
 */
import { router } from 'expo-router';

import { CartView, type CartLine } from '@/components/cart-view';
import { checkoutLine, pendingCheckoutLine } from '@/components/checkout-view';
import { AppRoutes } from '@/platform/navigation/app-routes';
import { pharmacyCartItemTotal, usePharmacyCartStore, usePharmacyCartTotals } from '@/stores/pharmacy-cart-store';

import type { PharmacyCartStoreHook } from './pharmacy-cart-action';

export const PHARMACY_CART_NOTICE = 'Your pharmacy cart is separate from food and grocery. All listed products are OTC.';

export type PharmacyCartScreenProps = {
  /** Test seam, mirroring the Dart widget's injectable `controller`. */
  cartStore?: PharmacyCartStoreHook;
};

export function PharmacyCartScreen({ cartStore = usePharmacyCartStore }: PharmacyCartScreenProps) {
  const items = cartStore((state) => state.items);
  const isLoading = cartStore((state) => state.isLoading);
  const increment = cartStore((state) => state.increment);
  const decrement = cartStore((state) => state.decrement);
  const removeProduct = cartStore((state) => state.removeProduct);
  const clearCart = cartStore((state) => state.clearCart);
  const totals = usePharmacyCartTotals(cartStore);

  const lines: CartLine[] = items.map((item) => ({
    id: item.product.id,
    name: item.product.name,
    total: pharmacyCartItemTotal(item),
    unitPrice: item.product.unitPrice,
    quantityLabel: `${item.quantity}`,
    imageUrl: item.product.imageUrl,
    onDecrease: () => decrement(item.product.id),
    onIncrease: item.quantity < item.product.stockQuantity ? () => increment(item.product.id) : null,
    onRemove: () => removeProduct(item.product.id),
  }));

  return (
    <CartView
      isLoading={isLoading}
      isEmpty={items.length === 0}
      emptyMessage="Your pharmacy cart is empty"
      browseLabel="Browse pharmacy"
      // `router.replace` mirrors the Dart `context.go(AppRoutes.pharmacy)`.
      onBrowse={() => router.replace(AppRoutes.pharmacy as never)}
      notice={PHARMACY_CART_NOTICE}
      fallbackIcon="medication"
      service="pharmacy"
      lines={lines}
      feeLines={[
        checkoutLine('Subtotal', totals.subtotal),
        totals.deliveryFee == null ? pendingCheckoutLine('Delivery fee') : checkoutLine('Delivery fee', totals.deliveryFee),
      ]}
      total={totals.total}
      // `router.push` mirrors the Dart `context.push(AppRoutes.pharmacyCheckout)`.
      onCheckout={() => router.push(AppRoutes.pharmacyCheckout as never)}
      onClear={clearCart}
    />
  );
}
