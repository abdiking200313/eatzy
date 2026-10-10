/**
 * Ports `flutter_app/lib/services/grocery/presentation/grocery_checkout.dart`
 * (`GroceryCheckout.validate`/`confirmOrder`) together with
 * `GroceryController.validateCheckout`/`confirmOrder`'s cart snapshot
 * (issue #392 / P7-04).
 *
 * Kept as plain functions (no React) so the Flutter controller-test cases
 * can be ported as unit tests. The in-flight guard (`isSubmitting`) lives
 * in `GroceryCheckoutScreen`, the same split the food checkout (#387) uses.
 *
 * Deviations from Flutter:
 * - No local activity record: RN's activity feed reads the server's
 *   `customer_activity` view, which already includes the new order (same
 *   as the food checkout).
 * - No demo `fallbackOrder`: `placeGroceryOrder` never returns `null`, so a
 *   missing order fails the submission instead of fabricating an order id.
 */
import { ErrorReporting } from '@/platform/error-reporting/error-reporter';
import { confirmDemoOrder } from '@/platform/orders/confirm-order-flow';
import type { DeliveryDetails } from '@/platform/orders/delivery-details';
import { generateIdempotencyKey } from '@/platform/orders/idempotency-key';
import { describeOrderSaveError } from '@/platform/orders/order-errors';
import type { PlacedOrder } from '@/platform/orders/placed-order';
import { selectGroceryCartStoreId, type GroceryCartLine } from '@/stores/grocery-cart-store';

import {
  placeGroceryOrder,
  type GroceryDeliverySlot,
  type GroceryOrderRequest,
  type GrocerySubstitutionPreference,
} from './api/grocery-order-repository';

export const GROCERY_EMPTY_CART_ERROR = 'Add at least one grocery item.';
export const GROCERY_SLOT_ERROR = 'Choose a delivery slot.';
export const GROCERY_SUBSTITUTION_ERROR = 'Choose a substitution preference.';
export const GROCERY_ORDER_SAVE_FAILED_MESSAGE = 'The grocery order could not be saved. Please try again.';

/** Ports `GroceryOrderConfirmation` (minus `createdAt`, which only fed the in-memory activity record). */
export interface GroceryOrderConfirmation {
  orderId: string;
  /** The RPC's authoritative total, in integer cents. */
  amount: number;
  slot: GroceryDeliverySlot;
  substitutionPreference: GrocerySubstitutionPreference;
}

/** Ports `GroceryCheckoutResult`. */
export type GroceryCheckoutResult =
  | { isSuccess: true; errors: []; confirmation: GroceryOrderConfirmation }
  | { isSuccess: false; errors: string[] };

/** Ports `GroceryCheckout.validate`. No address is asked for (owner decision, 2026-09-25). */
export function validateGroceryCheckout({
  cartIsEmpty,
  slot,
  substitutionPreference,
}: {
  cartIsEmpty: boolean;
  slot: GroceryDeliverySlot | null;
  substitutionPreference: GrocerySubstitutionPreference | null;
}): string[] {
  const errors: string[] = [];
  if (cartIsEmpty) errors.push(GROCERY_EMPTY_CART_ERROR);
  if (slot == null) errors.push(GROCERY_SLOT_ERROR);
  if (substitutionPreference == null) errors.push(GROCERY_SUBSTITUTION_ERROR);
  return errors;
}

export interface ConfirmGroceryOrderOptions {
  lines: GroceryCartLine[];
  delivery?: DeliveryDetails;
  slot: GroceryDeliverySlot | null;
  substitutionPreference: GrocerySubstitutionPreference | null;
  /** Clears (and persists) the cart once the order is placed. Awaited before this resolves. */
  clearCart: () => void | Promise<void>;
  /**
   * Identifies this checkout attempt; forwarded to `place_grocery_order` so
   * a retry with the same key returns the existing order. A fresh key is
   * generated when omitted (no protection across calls).
   */
  idempotencyKey?: string;
  /** Test seam; defaults to the real `placeGroceryOrder`. */
  placeOrder?: (request: GroceryOrderRequest) => Promise<PlacedOrder>;
}

/**
 * Ports `GroceryController.confirmOrder` → `GroceryCheckout.confirmOrder`:
 * validates, places the order through the shared `confirmDemoOrder` flow,
 * and clears the cart. Every `place_grocery_order` failure -- including the
 * elapsed-delivery-window exception (issue #82) -- maps to the generic
 * "could not be saved" message, except the missing-contact-details one
 * (`describeOrderSaveError`), exactly like Flutter.
 */
export function confirmGroceryOrder({
  lines,
  delivery = { note: '' },
  slot,
  substitutionPreference,
  clearCart,
  idempotencyKey,
  placeOrder = placeGroceryOrder,
}: ConfirmGroceryOrderOptions): Promise<GroceryCheckoutResult> {
  const validation = validateGroceryCheckout({ cartIsEmpty: lines.length === 0, slot, substitutionPreference });
  const storeId = selectGroceryCartStoreId(lines);
  const items = lines.map((line) => ({ productId: line.product.id, quantity: line.quantity }));
  const resolvedKey = idempotencyKey ?? generateIdempotencyKey();

  return confirmDemoOrder<GroceryCheckoutResult, string[], PlacedOrder>({
    validation,
    isValid: (errors) => errors.length === 0,
    onInvalid: (errors) => ({ isSuccess: false, errors }),
    placeOrder: () =>
      placeOrder({
        storeId: storeId!,
        deliverySlotId: slot!.id,
        delivery,
        substitutionPreference: substitutionPreference!,
        items,
        idempotencyKey: resolvedKey,
      }),
    fallbackOrder: () => {
      throw new Error('place_grocery_order returned no order.');
    },
    onSaveFailed: (error) => {
      ErrorReporting.instance.reportError(error, undefined, 'GroceryController.confirmOrder');
      return { isSuccess: false, errors: [describeOrderSaveError(error, GROCERY_ORDER_SAVE_FAILED_MESSAGE)] };
    },
    recordActivity: () => {},
    clearCart,
    onConfirmed: (order) => ({
      isSuccess: true,
      errors: [],
      confirmation: { orderId: order.orderId, amount: order.total, slot: slot!, substitutionPreference: substitutionPreference! },
    }),
  });
}
