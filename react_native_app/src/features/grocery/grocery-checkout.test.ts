/**
 * Ports the checkout cases of `flutter_app/test/grocery_controller_test.dart`
 * (issue #392 / P7-04) against `confirmGroceryOrder`/`validateGroceryCheckout`
 * (the RN home of `GroceryController.confirmOrder`/`validateCheckout`).
 *
 * Ported:
 * - 'requires and records the selected substitution preference' (minus the
 *   activity-record assertions -- RN keeps no client-side activity record,
 *   see grocery-checkout.ts).
 * - 'checkout validates cart, slot, and preference — no address'.
 * - 'confirmOrder surfaces an error, resets loading, and keeps the cart
 *   when the order repository throws'.
 * - 'confirmOrder surfaces a generic error ... when place_grocery_order
 *   rejects an elapsed delivery slot (issue #82)'.
 * - 'confirmOrder forwards a caller-supplied idempotency key ... and
 *   synthesizes one when none is given (issue #59)'.
 * - 'confirmOrder records the RPC-returned total, not the client cart
 *   total (issue #60)' (confirmation half; no activity feed client-side).
 *
 * Ported in `grocery-checkout-screen.test.tsx` instead: 'confirmOrder
 * ignores a second call while a submission is in flight (issue #59)' --
 * the in-flight guard lives in the screen in RN, as for food.
 *
 * Already covered elsewhere: the cart/quantity/persistence cases
 * (`grocery-cart-store.test.ts`, #376) and the catalog-staleness group
 * (store screens, #389/#390).
 */
import { PostgrestError } from '@supabase/supabase-js';

import { missingContactDetailsMessage } from '@/platform/orders/order-errors';
import type { PlacedOrder } from '@/platform/orders/placed-order';
import type { GroceryCartLine, GroceryProduct } from '@/stores/grocery-cart-store';

import type { GroceryDeliverySlot, GroceryOrderRequest } from './api/grocery-order-repository';
import {
  confirmGroceryOrder,
  GROCERY_ORDER_SAVE_FAILED_MESSAGE,
  validateGroceryCheckout,
} from './grocery-checkout';

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

const rice: GroceryProduct = {
  id: 'bakaal-rice',
  storeId: 'bakaal-fresh',
  name: 'Basmati rice',
  description: 'One 5 kg bag',
  unitPrice: 850,
  pricingUnit: 'each',
  stockState: 'inStock',
  availableQuantity: 24,
  icon: '🛒',
};
const riceLine: GroceryCartLine = { product: rice, quantity: 1 };

const slot: GroceryDeliverySlot = { id: 'today-afternoon', label: 'Today', detail: '2:00 PM – 4:00 PM' };
const delivery = { note: 'Near Taleex Road' };

const placed: PlacedOrder = { orderId: 'grocery-order-1', subtotal: 1000, deliveryFee: 250, tax: 0, total: 1250 };

beforeEach(() => {
  // `ErrorReporting`'s default reporter logs failed submissions via console.error.
  jest.spyOn(console, 'error').mockImplementation(() => {});
});

afterEach(() => {
  jest.restoreAllMocks();
});

describe('validateGroceryCheckout', () => {
  it('validates cart, slot, and preference — no address', () => {
    const errors = validateGroceryCheckout({ cartIsEmpty: true, slot: null, substitutionPreference: null });

    expect(errors).toContain('Add at least one grocery item.');
    expect(errors).toHaveLength(3);
    expect(errors).toContain('Choose a delivery slot.');
    expect(errors).toContain('Choose a substitution preference.');
  });
});

describe('confirmGroceryOrder', () => {
  it('requires and records the selected substitution preference', async () => {
    const placeOrder = jest.fn(async () => placed);
    const clearCart = jest.fn();

    const missingPreference = await confirmGroceryOrder({
      lines: [riceLine],
      delivery,
      slot,
      substitutionPreference: null,
      clearCart,
      placeOrder,
    });
    expect(missingPreference.isSuccess).toBe(false);
    expect(missingPreference.errors).toContain('Choose a substitution preference.');
    expect(placeOrder).not.toHaveBeenCalled();
    expect(clearCart).not.toHaveBeenCalled();

    const result = await confirmGroceryOrder({
      lines: [riceLine],
      delivery,
      slot,
      substitutionPreference: 'contactMe',
      clearCart,
      placeOrder,
    });

    expect(result.isSuccess).toBe(true);
    if (!result.isSuccess) throw new Error('expected success');
    expect(result.confirmation.substitutionPreference).toBe('contactMe');
    expect(result.confirmation.slot).toEqual(slot);
    expect(clearCart).toHaveBeenCalledTimes(1);
    expect(placeOrder).toHaveBeenCalledWith(
      expect.objectContaining({
        storeId: 'bakaal-fresh',
        deliverySlotId: 'today-afternoon',
        substitutionPreference: 'contactMe',
        delivery,
        items: [{ productId: 'bakaal-rice', quantity: 1 }],
      }),
    );
  });

  it('surfaces an error and keeps the cart when the order repository throws', async () => {
    const clearCart = jest.fn();
    const result = await confirmGroceryOrder({
      lines: [riceLine],
      delivery,
      slot,
      substitutionPreference: 'contactMe',
      clearCart,
      placeOrder: async () => {
        throw new Error('Simulated network failure while placing grocery order');
      },
    });

    expect(result.isSuccess).toBe(false);
    expect(result.errors).toContain(GROCERY_ORDER_SAVE_FAILED_MESSAGE);
    expect(clearCart).not.toHaveBeenCalled();
  });

  it('surfaces the generic error and keeps the cart when place_grocery_order rejects an elapsed delivery slot (issue #82)', async () => {
    const clearCart = jest.fn();
    const result = await confirmGroceryOrder({
      lines: [riceLine],
      delivery,
      slot,
      substitutionPreference: 'contactMe',
      clearCart,
      placeOrder: async () => {
        throw new PostgrestError({
          message: 'The selected delivery window has already passed. Please choose another delivery slot.',
          details: '',
          hint: '',
          code: 'P0001',
        });
      },
    });

    expect(result.isSuccess).toBe(false);
    expect(result.errors).toContain('The grocery order could not be saved. Please try again.');
    expect(result.errors.join()).not.toContain('delivery window has already passed');
    expect(clearCart).not.toHaveBeenCalled();
  });

  it('surfaces the server message when the profile has no name or phone', async () => {
    const result = await confirmGroceryOrder({
      lines: [riceLine],
      slot,
      substitutionPreference: 'bestMatch',
      clearCart: jest.fn(),
      placeOrder: async () => {
        throw new PostgrestError({ message: missingContactDetailsMessage, details: '', hint: '', code: 'P0001' });
      },
    });

    expect(result.errors).toEqual([`${missingContactDetailsMessage}.`]);
  });

  it('forwards a caller-supplied idempotency key, and synthesizes one when none is given (issue #59)', async () => {
    const requests: GroceryOrderRequest[] = [];
    const placeOrder = async (request: GroceryOrderRequest) => {
      requests.push(request);
      return placed;
    };

    await confirmGroceryOrder({
      lines: [riceLine],
      delivery,
      slot,
      substitutionPreference: 'contactMe',
      clearCart: jest.fn(),
      idempotencyKey: 'attempt-key-1',
      placeOrder,
    });
    expect(requests[0].idempotencyKey).toBe('attempt-key-1');

    await confirmGroceryOrder({
      lines: [riceLine],
      delivery,
      slot,
      substitutionPreference: 'contactMe',
      clearCart: jest.fn(),
      placeOrder,
    });
    expect(requests[1].idempotencyKey).toEqual(expect.any(String));
    expect(requests[1].idempotencyKey).not.toHaveLength(0);
  });

  it('records the RPC-returned total, not the client cart total (issue #60)', async () => {
    const result = await confirmGroceryOrder({
      lines: [riceLine],
      delivery,
      slot,
      substitutionPreference: 'contactMe',
      clearCart: jest.fn(),
      placeOrder: async () => ({ orderId: 'grocery-server-order', subtotal: 5000, deliveryFee: 250, tax: 0, total: 5250 }),
    });

    expect(result.isSuccess).toBe(true);
    if (!result.isSuccess) throw new Error('expected success');
    expect(result.confirmation.amount).toBe(5250);
    expect(result.confirmation.orderId).toBe('grocery-server-order');
  });
});
