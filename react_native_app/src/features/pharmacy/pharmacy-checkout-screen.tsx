/**
 * Ports `flutter_app/lib/services/pharmacy/presentation/pharmacy_checkout_screen.dart`'s
 * `PharmacyCheckoutScreen` (issue #395 / P7-07): the shared `CheckoutView`
 * with an optional delivery note, placing a real order via
 * `place_pharmacy_order` (`placePharmacyCheckoutOrder` in
 * `pharmacy-checkout.ts`). The server prices every line; the client only
 * sends product ids and quantities.
 *
 * Double-submit protection mirrors the food (#387) and grocery (#392)
 * checkouts: a ref-based in-flight guard (the RN home of
 * `PharmacyController.isSubmitting`) plus the button disabled while
 * submitting, and one idempotency key per visit to this screen, reused for
 * every retry.
 *
 * Deviation from Flutter: the "order placed" confirmation is a native
 * `Alert` (with the order reference, as in `showOrderPlacedDialog`) rather
 * than an awaited dialog; navigation to the activity tab happens right away
 * -- same as the grocery port.
 */
import { router } from 'expo-router';
import { useRef, useState } from 'react';
import { Alert } from 'react-native';

import { CheckoutView, checkoutLine, pendingCheckoutLine } from '@/components/checkout-view';
import { AppRoutes } from '@/platform/navigation/app-routes';
import { generateIdempotencyKey } from '@/platform/orders/idempotency-key';
import type { PlacedOrder } from '@/platform/orders/placed-order';
import { pharmacyCartItemTotal, usePharmacyCartStore, usePharmacyCartTotals } from '@/stores/pharmacy-cart-store';

import type { PharmacyOrderRequest } from './api/pharmacy-order-repository';
import type { PharmacyCartStoreHook } from './pharmacy-cart-action';
import { pharmacyCheckoutErrorText, placePharmacyCheckoutOrder, type PharmacyCheckoutErrors } from './pharmacy-checkout';

export type PharmacyCheckoutScreenProps = {
  /** Test seam, mirroring the Dart widget's injectable `controller`. */
  cartStore?: PharmacyCartStoreHook;
  /** Test seam; defaults to the real `placePharmacyOrder`. */
  placeOrder?: (request: PharmacyOrderRequest) => Promise<PlacedOrder>;
};

export function PharmacyCheckoutScreen({ cartStore = usePharmacyCartStore, placeOrder }: PharmacyCheckoutScreenProps) {
  const items = cartStore((state) => state.items);
  const isLoading = cartStore((state) => state.isLoading);
  const clearCart = cartStore((state) => state.clearCart);
  const totals = usePharmacyCartTotals(cartStore);

  const [note, setNote] = useState('');
  const [errors, setErrors] = useState<PharmacyCheckoutErrors>({});
  const [isSubmitting, setIsSubmitting] = useState(false);
  const inFlight = useRef(false);
  // Generated once per visit to this screen and reused for every retry.
  const [idempotencyKey] = useState(generateIdempotencyKey);

  async function submit() {
    if (inFlight.current) return;
    inFlight.current = true;
    setIsSubmitting(true);

    let result;
    try {
      result = await placePharmacyCheckoutOrder({
        items,
        delivery: { note },
        clearCart,
        idempotencyKey,
        placeOrder,
      });
    } finally {
      inFlight.current = false;
      setIsSubmitting(false);
    }
    setErrors(result.errors);
    if (!result.isSuccess) return;

    Alert.alert('Order placed', `${result.message}\n\nReference: ${result.orderId}`);
    router.replace(AppRoutes.activity as never);
  }

  return (
    <CheckoutView
      title="Checkout"
      isLoading={isLoading}
      isEmpty={items.length === 0}
      emptyMessage="Your pharmacy cart is empty"
      browseLabel="Browse OTC products"
      // `router.replace` mirrors the Dart `context.go(AppRoutes.pharmacy)`.
      onBrowse={() => router.replace(AppRoutes.pharmacy as never)}
      note={note}
      onNoteChange={setNote}
      itemLines={items.map((item) => checkoutLine(`${item.product.name} ×${item.quantity}`, pharmacyCartItemTotal(item)))}
      feeLines={[
        checkoutLine('Subtotal', totals.subtotal),
        totals.deliveryFee == null ? pendingCheckoutLine('Delivery fee') : checkoutLine('Delivery fee', totals.deliveryFee),
      ]}
      total={totals.total}
      isSubmitting={isSubmitting}
      errorText={pharmacyCheckoutErrorText(errors)}
      onSubmit={() => void submit()}
    />
  );
}
