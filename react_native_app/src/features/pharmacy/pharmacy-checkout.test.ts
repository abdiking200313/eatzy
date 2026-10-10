/**
 * Ports the checkout cases of `flutter_app/test/pharmacy_controller_test.dart`
 * (issue #395 / P7-07) against `placePharmacyCheckoutOrder`/
 * `validatePharmacyCheckout` (the RN home of
 * `PharmacyController.placeDemoOrder`/`validateCheckout`).
 *
 * Ported:
 * - 'checkout validates only the cart — no address'.
 * - 'demo checkout records pharmacy activity and clears its cart' (minus the
 *   activity-record assertions -- RN keeps no client-side activity record,
 *   see pharmacy-checkout.ts).
 * - 'placeDemoOrder surfaces an error, resets loading, and keeps the cart
 *   when the order repository throws'.
 * - 'placeDemoOrder forwards a caller-supplied idempotency key ... and
 *   synthesizes one when none is given (issue #59)'.
 * - 'placeDemoOrder records the RPC-returned total, not the client cart
 *   total (issue #60)' (result half; no activity feed client-side).
 *
 * Ported in `pharmacy-checkout-screen.test.tsx` instead: 'placeDemoOrder
 * ignores a second call while a submission is in flight (issue #59)' --
 * the in-flight guard lives in the screen in RN, as for food and grocery.
 */
import { PostgrestError } from '@supabase/supabase-js';

import { missingContactDetailsMessage } from '@/platform/orders/order-errors';
import type { PlacedOrder } from '@/platform/orders/placed-order';
import type { PharmacyCartItem, PharmacyProduct } from '@/stores/pharmacy-cart-store';

import type { PharmacyOrderRequest } from './api/pharmacy-order-repository';
import {
  pharmacyCheckoutErrorText,
  placePharmacyCheckoutOrder,
  PHARMACY_EMPTY_CART_ERROR,
  PHARMACY_ORDER_SAVE_FAILED_MESSAGE,
  PHARMACY_STOCK_ERROR,
  validatePharmacyCheckout,
} from './pharmacy-checkout';

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

const paracetamol: PharmacyProduct = {
  id: 'pain-paracetamol',
  storeId: 'legacy-pharmacy',
  name: 'Paracetamol',
  description: 'Pain relief',
  category: 'Pain relief',
  unitPrice: 275,
  stockQuantity: 24,
  saleType: 'overTheCounter',
};
const paracetamolLine: PharmacyCartItem = { product: paracetamol, quantity: 1 };
const delivery = { note: 'Taleex Road, blue gate' };
const placed: PlacedOrder = { orderId: 'pharmacy-order-1', subtotal: 275, deliveryFee: 250, tax: 0, total: 525 };

beforeEach(() => {
  // `ErrorReporting`'s default reporter logs failed submissions via console.error.
  jest.spyOn(console, 'error').mockImplementation(() => {});
});

afterEach(() => {
  jest.restoreAllMocks();
});

describe('validatePharmacyCheckout', () => {
  it('validates only the cart — no address', () => {
    expect(validatePharmacyCheckout([])).toEqual({ cart: PHARMACY_EMPTY_CART_ERROR });
  });

  it('flags a line that is no longer OTC, out of stock, or over its stock', () => {
    expect(validatePharmacyCheckout([paracetamolLine])).toEqual({});
    expect(validatePharmacyCheckout([{ product: { ...paracetamol, saleType: 'prescriptionOnly' }, quantity: 1 }])).toEqual({
      stock: PHARMACY_STOCK_ERROR,
    });
    expect(validatePharmacyCheckout([{ product: { ...paracetamol, stockQuantity: 0 }, quantity: 1 }])).toEqual({
      stock: PHARMACY_STOCK_ERROR,
    });
    expect(validatePharmacyCheckout([{ product: { ...paracetamol, stockQuantity: 2 }, quantity: 3 }])).toEqual({
      stock: PHARMACY_STOCK_ERROR,
    });
  });

  it('shows the cart error first, then stock, then order -- like the screen', () => {
    expect(pharmacyCheckoutErrorText({ cart: 'a', stock: 'b', order: 'c' })).toBe('a');
    expect(pharmacyCheckoutErrorText({ stock: 'b', order: 'c' })).toBe('b');
    expect(pharmacyCheckoutErrorText({ order: 'c' })).toBe('c');
    expect(pharmacyCheckoutErrorText({})).toBeNull();
  });
});

describe('placePharmacyCheckoutOrder', () => {
  it('places the order with ids and quantities only, then clears the cart', async () => {
    const placeOrder = jest.fn(async (_request: PharmacyOrderRequest) => placed);
    const clearCart = jest.fn();

    const result = await placePharmacyCheckoutOrder({
      items: [{ product: paracetamol, quantity: 2 }],
      delivery,
      clearCart,
      idempotencyKey: 'attempt-key-1',
      placeOrder,
    });

    expect(result.isSuccess).toBe(true);
    expect(result.message).toContain('Pay on delivery');
    expect(placeOrder).toHaveBeenCalledWith({
      delivery,
      items: [{ productId: 'pain-paracetamol', quantity: 2 }],
      idempotencyKey: 'attempt-key-1',
    });
    expect(clearCart).toHaveBeenCalledTimes(1);
  });

  it('does not call the RPC for an invalid cart', async () => {
    const placeOrder = jest.fn(async (_request: PharmacyOrderRequest) => placed);

    const result = await placePharmacyCheckoutOrder({ items: [], clearCart: jest.fn(), placeOrder });

    expect(result.isSuccess).toBe(false);
    expect(result.errors.cart).toBe(PHARMACY_EMPTY_CART_ERROR);
    expect(placeOrder).not.toHaveBeenCalled();
  });

  it('surfaces an error and keeps the cart when the order repository throws', async () => {
    const clearCart = jest.fn();

    const result = await placePharmacyCheckoutOrder({
      items: [paracetamolLine],
      delivery,
      clearCart,
      placeOrder: async () => {
        throw new Error('network down');
      },
    });

    expect(result.isSuccess).toBe(false);
    expect(result.errors.order).toContain('The pharmacy order could not be saved');
    expect(result.errors.order).toBe(PHARMACY_ORDER_SAVE_FAILED_MESSAGE);
    expect(clearCart).not.toHaveBeenCalled();
  });

  it('surfaces the missing-contact-details message instead of the generic one', async () => {
    const result = await placePharmacyCheckoutOrder({
      items: [paracetamolLine],
      clearCart: jest.fn(),
      placeOrder: async () => {
        throw new PostgrestError({ message: missingContactDetailsMessage, details: '', hint: '', code: 'P0001' });
      },
    });

    expect(result.errors.order).toBe(`${missingContactDetailsMessage}.`);
  });

  it('forwards a caller-supplied idempotency key, and synthesizes one when none is given (issue #59)', async () => {
    const placeOrder = jest.fn(async (_request: PharmacyOrderRequest) => placed);

    await placePharmacyCheckoutOrder({ items: [paracetamolLine], delivery, clearCart: jest.fn(), idempotencyKey: 'attempt-key-1', placeOrder });
    expect(placeOrder.mock.calls[0][0].idempotencyKey).toBe('attempt-key-1');

    await placePharmacyCheckoutOrder({ items: [paracetamolLine], delivery, clearCart: jest.fn(), placeOrder });
    const generated = placeOrder.mock.calls[1][0].idempotencyKey;
    expect(generated).toEqual(expect.any(String));
    expect(generated).not.toHaveLength(0);
  });

  it('returns the RPC total, not the client cart total (issue #60)', async () => {
    const serverPriced: PlacedOrder = { orderId: 'pharmacy-server-order', subtotal: 4000, deliveryFee: 250, tax: 0, total: 4250 };

    const result = await placePharmacyCheckoutOrder({
      items: [paracetamolLine],
      delivery,
      clearCart: jest.fn(),
      placeOrder: async () => serverPriced,
    });

    expect(result.isSuccess).toBe(true);
    if (result.isSuccess) {
      expect(result.orderId).toBe('pharmacy-server-order');
      expect(result.total).toBe(4250);
    }
  });
});
