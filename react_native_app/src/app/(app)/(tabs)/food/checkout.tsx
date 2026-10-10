/**
 * Ports flutter_app/lib/services/food/presentation/checkout_screen.dart's
 * `CheckoutScreen` together with `food_controller.dart`'s
 * `FoodController.confirmOrder` (issue #387 / P6-06): the food checkout,
 * rendered through the shared `CheckoutView` (#379) against the app-wide
 * `useFoodCartStore`/`useFoodCartTotals` (#376), placing a real order via
 * `place_food_order` (`placeFoodOrder`).
 *
 * Only ids and quantities are sent; the server prices the order. The totals
 * shown here are the cart's client-side estimate, exactly like Flutter.
 *
 * Double-submit protection mirrors Flutter's two layers:
 * - an in-flight guard (a ref, so a second tap in the same render frame --
 *   before `isSubmitting` state has re-rendered the disabled button -- is
 *   still dropped), plus the button itself being disabled while submitting;
 * - one idempotency key per visit to this screen, reused for every retry of
 *   that attempt, so a lost response followed by a retry collapses into
 *   the original order server-side.
 *
 * Deviations from Flutter:
 * - On success this opens order tracking (`trackOrderDetailsPath`) instead
 *   of the activity tab, per issue #387; the "order placed" confirmation is
 *   a non-blocking `Alert` instead of an awaited dialog.
 * - No local activity record: Flutter's `ActivityController.record` is an
 *   in-memory optimistic cache, but RN's activity feed is read straight
 *   from the server's `customer_activity` view (which already includes the
 *   new order), so there is nothing to record client-side.
 * - Flutter's `fallbackOrder` synthesizes a demo order when an injected
 *   repository returns `null`; `placeFoodOrder` never does, so the fallback
 *   here fails the submission instead of fabricating an order id.
 */
import { router } from 'expo-router';
import { useRef, useState } from 'react';
import { Alert } from 'react-native';

import { CheckoutView, checkoutLine, pendingCheckoutLine } from '@/components/checkout-view';
import { placeFoodOrder } from '@/features/food/api/food-order-repository';
import { ErrorReporting } from '@/platform/error-reporting/error-reporter';
import { AppRoutes, trackOrderDetailsPath } from '@/platform/navigation/app-routes';
import { confirmDemoOrder } from '@/platform/orders/confirm-order-flow';
import { generateIdempotencyKey } from '@/platform/orders/idempotency-key';
import { describeOrderSaveError } from '@/platform/orders/order-errors';
import type { PlacedOrder } from '@/platform/orders/placed-order';
import { cartItemTotal, FOOD_SERVICE_ID, useFoodCartStore, useFoodCartTotals } from '@/stores/food-cart-store';

const FOOD_ORDER_SAVE_FAILED_MESSAGE = 'The food order could not be saved. Please try again.';

type FoodCheckoutResult = { isSuccess: true; orderId: string } | { isSuccess: false; error: string | null };

export default function FoodCheckoutScreen() {
  const items = useFoodCartStore((state) => state.items);
  const isLoading = useFoodCartStore((state) => state.isLoading);
  const clear = useFoodCartStore((state) => state.clear);
  const totals = useFoodCartTotals();

  const [note, setNote] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submissionError, setSubmissionError] = useState<string | null>(null);
  const inFlight = useRef(false);
  // Generated once per visit to this screen and reused for every retry --
  // see this file's top comment.
  const [idempotencyKey] = useState(generateIdempotencyKey);

  async function placeOrder() {
    const restaurantId = totals.restaurantId;
    if (inFlight.current || restaurantId == null || items.length === 0) {
      return;
    }
    inFlight.current = true;
    setIsSubmitting(true);
    setSubmissionError(null);

    let result: FoodCheckoutResult;
    try {
      const orderItems = items.map((item) => ({ menuItemId: item.menuItemId, quantity: item.quantity }));
      result = await confirmDemoOrder<FoodCheckoutResult, boolean, PlacedOrder>({
        validation: true,
        isValid: (isValid) => isValid,
        onInvalid: () => ({ isSuccess: false, error: null }),
        placeOrder: () =>
          placeFoodOrder({
            restaurantId,
            delivery: { note },
            items: orderItems,
            idempotencyKey,
          }),
        fallbackOrder: () => {
          throw new Error('place_food_order returned no order.');
        },
        onSaveFailed: (error) => {
          ErrorReporting.instance.reportError(error, undefined, 'FoodCheckoutScreen.placeOrder');
          return { isSuccess: false, error: describeOrderSaveError(error, FOOD_ORDER_SAVE_FAILED_MESSAGE) };
        },
        recordActivity: () => {},
        clearCart: clear,
        onConfirmed: (order) => ({ isSuccess: true, orderId: order.orderId }),
      });
    } finally {
      inFlight.current = false;
      setIsSubmitting(false);
    }
    if (!result.isSuccess) {
      setSubmissionError(result.error);
      return;
    }
    Alert.alert('Order placed', 'Your order was sent to the restaurant. Pay on delivery.');
    router.replace(trackOrderDetailsPath({ serviceId: FOOD_SERVICE_ID, orderId: result.orderId }) as never);
  }

  return (
    <CheckoutView
      title="Checkout"
      isLoading={isLoading}
      isEmpty={items.length === 0}
      emptyMessage="Your cart is empty"
      browseLabel="Browse restaurants"
      // `router.replace` mirrors the Dart `context.go(AppRoutes.mainApp)`.
      onBrowse={() => router.replace(AppRoutes.mainApp as never)}
      note={note}
      onNoteChange={setNote}
      itemLines={items.map((item) => checkoutLine(`${item.name} ×${item.quantity}`, cartItemTotal(item)))}
      feeLines={[
        checkoutLine('Subtotal', totals.subtotal),
        totals.tax == null ? pendingCheckoutLine('Tax') : checkoutLine('Tax', totals.tax),
        totals.deliveryFee == null
          ? pendingCheckoutLine('Delivery fee')
          : checkoutLine('Delivery fee', totals.deliveryFee),
      ]}
      total={totals.total}
      isSubmitting={isSubmitting}
      errorText={submissionError}
      onSubmit={() => void placeOrder()}
    />
  );
}
