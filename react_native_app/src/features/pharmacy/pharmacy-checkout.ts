/**
 * Ports `PharmacyCheckoutValidation`/`PharmacyCheckoutResult` from
 * `flutter_app/lib/services/pharmacy/models/pharmacy_checkout.dart` together
 * with `PharmacyController.validateCheckout`/`placeDemoOrder` from
 * `.../presentation/pharmacy_controller.dart` (issue #395 / P7-07).
 *
 * Kept as plain functions (no React) so the Flutter controller-test cases
 * can be ported as unit tests. The in-flight guard (`isSubmitting`) lives in
 * `PharmacyCheckoutScreen`, the same split the food (#387) and grocery
 * (#392) checkouts use.
 *
 * The OTC rules are exactly Flutter's: the cart only ever accepts
 * over-the-counter, in-stock products (`addProduct`), and checkout
 * re-checks that every line is still OTC, available, and within stock.
 * No prescription or regulated-product flow exists in Flutter, so none is
 * added here.
 *
 * Deviations from Flutter:
 * - No local activity record: RN's activity feed reads the server's
 *   `customer_activity` view, which already includes the new order (same
 *   as the food and grocery checkouts).
 * - No demo `fallbackOrder`: `placePharmacyOrder` never returns `null`, so a
 *   missing order fails the submission instead of fabricating an order id.
 */
import { ErrorReporting } from '@/platform/error-reporting/error-reporter';
import { confirmDemoOrder } from '@/platform/orders/confirm-order-flow';
import { EMPTY_DELIVERY_DETAILS, type DeliveryDetails } from '@/platform/orders/delivery-details';
import { generateIdempotencyKey } from '@/platform/orders/idempotency-key';
import { describeOrderSaveError } from '@/platform/orders/order-errors';
import type { PlacedOrder } from '@/platform/orders/placed-order';
import {
  isPharmacyProductAvailable,
  isPharmacyProductOverTheCounter,
  type PharmacyCartItem,
} from '@/stores/pharmacy-cart-store';

import { placePharmacyOrder, type PharmacyOrderRequest } from './api/pharmacy-order-repository';

export const PHARMACY_EMPTY_CART_ERROR = 'Add at least one OTC product before checkout.';
export const PHARMACY_STOCK_ERROR = 'One or more products are not eligible for this OTC order.';
export const PHARMACY_ORDER_SAVE_FAILED_MESSAGE = 'The pharmacy order could not be saved. Please try again.';
export const PHARMACY_INVALID_MESSAGE = 'Please check your checkout details.';
export const PHARMACY_ORDER_PLACED_MESSAGE = 'Your order was sent to the pharmacy. Pay on delivery.';

/** The keys `PharmacyCheckoutValidation.errors` uses. */
export type PharmacyCheckoutErrorField = 'cart' | 'stock' | 'order';

/** Ports `PharmacyCheckoutValidation.errors`. Empty means valid. */
export type PharmacyCheckoutErrors = Partial<Record<PharmacyCheckoutErrorField, string>>;

/** Ports `PharmacyCheckoutResult`. */
export type PharmacyCheckoutResult =
  | { isSuccess: true; message: string; orderId: string; total: number; errors: PharmacyCheckoutErrors }
  | { isSuccess: false; message: string; errors: PharmacyCheckoutErrors };

/** Ports `PharmacyCheckoutResult.invalid`. */
export function pharmacyCheckoutInvalid(errors: PharmacyCheckoutErrors): PharmacyCheckoutResult {
  return { isSuccess: false, message: PHARMACY_INVALID_MESSAGE, errors };
}

/** Ports `PharmacyController.validateCheckout`: only the cart is checked -- there is no address. */
export function validatePharmacyCheckout(items: PharmacyCartItem[]): PharmacyCheckoutErrors {
  const errors: PharmacyCheckoutErrors = {};
  if (items.length === 0) {
    errors.cart = PHARMACY_EMPTY_CART_ERROR;
  }
  if (
    items.some(
      (item) =>
        !isPharmacyProductOverTheCounter(item.product) ||
        !isPharmacyProductAvailable(item.product) ||
        item.quantity > item.product.stockQuantity,
    )
  ) {
    errors.stock = PHARMACY_STOCK_ERROR;
  }
  return errors;
}

/** Mirrors the screen's `_errors['cart'] ?? _errors['stock'] ?? _errors['order']`. */
export function pharmacyCheckoutErrorText(errors: PharmacyCheckoutErrors): string | null {
  return errors.cart ?? errors.stock ?? errors.order ?? null;
}

export interface PlacePharmacyCheckoutOrderOptions {
  items: PharmacyCartItem[];
  delivery?: DeliveryDetails;
  /** Clears the cart once the order is placed. Awaited before this resolves. */
  clearCart: () => void | Promise<void>;
  /**
   * Identifies this checkout attempt; forwarded to `place_pharmacy_order` so
   * a retry with the same key returns the existing order. A fresh key is
   * generated when omitted (no protection across calls).
   */
  idempotencyKey?: string;
  /** Test seam; defaults to the real `placePharmacyOrder`. */
  placeOrder?: (request: PharmacyOrderRequest) => Promise<PlacedOrder>;
}

/**
 * Ports `PharmacyController.placeDemoOrder` (minus the `isSubmitting` guard,
 * which the screen owns): validates, places the order through the shared
 * `confirmDemoOrder` flow, and clears the cart. Every failure maps to the
 * generic "could not be saved" message except the missing-contact-details
 * one (`describeOrderSaveError`), exactly like Flutter.
 */
export function placePharmacyCheckoutOrder({
  items,
  delivery = EMPTY_DELIVERY_DETAILS,
  clearCart,
  idempotencyKey,
  placeOrder = placePharmacyOrder,
}: PlacePharmacyCheckoutOrderOptions): Promise<PharmacyCheckoutResult> {
  const validation = validatePharmacyCheckout(items);
  const lines = items.map((item) => ({ productId: item.product.id, quantity: item.quantity }));
  const resolvedKey = idempotencyKey ?? generateIdempotencyKey();

  return confirmDemoOrder<PharmacyCheckoutResult, PharmacyCheckoutErrors, PlacedOrder>({
    validation,
    isValid: (errors) => Object.keys(errors).length === 0,
    onInvalid: pharmacyCheckoutInvalid,
    placeOrder: () => placeOrder({ delivery, items: lines, idempotencyKey: resolvedKey }),
    fallbackOrder: () => {
      throw new Error('place_pharmacy_order returned no order.');
    },
    onSaveFailed: (error) => {
      ErrorReporting.instance.reportError(error, undefined, 'PharmacyController.placeDemoOrder');
      return pharmacyCheckoutInvalid({ order: describeOrderSaveError(error, PHARMACY_ORDER_SAVE_FAILED_MESSAGE) });
    },
    recordActivity: () => {},
    clearCart,
    onConfirmed: (order) => ({
      isSuccess: true,
      message: PHARMACY_ORDER_PLACED_MESSAGE,
      orderId: order.orderId,
      total: order.total,
      errors: {},
    }),
  });
}
