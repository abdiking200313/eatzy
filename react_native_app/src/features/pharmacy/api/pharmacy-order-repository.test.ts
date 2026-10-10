/**
 * Covers `pharmacy-order-repository.ts` (issue #395 / P7-07): the
 * `PharmacyOrderRequest.toRpcParams`/`PharmacyOrderLineInput.toRpcMap`
 * validation and the `place_pharmacy_order` call against the fake Supabase
 * client. Flutter has no dedicated test file for these; the request-shape
 * assertions mirror `grocery-order-repository.test.ts`.
 *
 * Whether an order really lands in the database cannot be verified from a
 * unit test (no live database); the exact RPC name/params asserted here
 * stand in for that.
 */
import { createFakeSupabaseClient, fakeSupabaseError, fakeSupabaseOk } from '@/test-utils/fake-supabase-client';

import {
  pharmacyOrderRequestToRpcParams,
  placePharmacyOrder,
  type PharmacyOrderRequest,
  type PharmacyOrderSource,
} from './pharmacy-order-repository';

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

const request: PharmacyOrderRequest = {
  delivery: { note: '  Taleex Road, blue gate  ' },
  items: [
    { productId: 'pain-paracetamol', quantity: 2 },
    { productId: 'first-aid-bandages', quantity: 1 },
  ],
  idempotencyKey: 'attempt-1',
};

describe('pharmacyOrderRequestToRpcParams', () => {
  it('sends ids, quantities and the idempotency key -- never a price, a store id or an address id', () => {
    expect(pharmacyOrderRequestToRpcParams(request)).toEqual({
      p_recipient_name: '',
      p_phone: '',
      p_street: 'Taleex Road, blue gate',
      p_district: '',
      p_city: '',
      p_delivery_instructions: '',
      p_items: [
        { product_id: 'pain-paracetamol', quantity: 2 },
        { product_id: 'first-aid-bandages', quantity: 1 },
      ],
      p_idempotency_key: 'attempt-1',
    });
  });

  it('defaults the delivery note to empty and the idempotency key to null', () => {
    const params = pharmacyOrderRequestToRpcParams({ items: request.items });
    expect(params.p_street).toBe('');
    expect(params.p_idempotency_key).toBeNull();
  });

  it('rejects no items, a blank product id, and a non-positive quantity', () => {
    expect(() => pharmacyOrderRequestToRpcParams({ ...request, items: [] })).toThrow('A pharmacy order requires at least one item.');
    expect(() => pharmacyOrderRequestToRpcParams({ ...request, items: [{ productId: ' ', quantity: 1 }] })).toThrow(
      'A pharmacy product ID is required.',
    );
    expect(() => pharmacyOrderRequestToRpcParams({ ...request, items: [{ productId: 'x', quantity: 0 }] })).toThrow(
      'Pharmacy quantity must be positive.',
    );
  });
});

describe('placePharmacyOrder', () => {
  it('calls place_pharmacy_order and returns the server-computed totals', async () => {
    const client = createFakeSupabaseClient();
    client.queueRpcResponse(
      'place_pharmacy_order',
      fakeSupabaseOk([{ order_id: 'pharmacy-order-1', subtotal: 875, delivery_fee: 250, tax: 0, total: 1125 }]),
    );

    const placed = await placePharmacyOrder(request, client as unknown as PharmacyOrderSource);

    expect(placed).toEqual({ orderId: 'pharmacy-order-1', subtotal: 875, deliveryFee: 250, tax: 0, total: 1125 });
    expect(client.calls[0]).toEqual(
      expect.objectContaining({ kind: 'rpc', name: 'place_pharmacy_order', params: pharmacyOrderRequestToRpcParams(request) }),
    );
  });

  it('rethrows the RPC error as-is', async () => {
    const client = createFakeSupabaseClient();
    client.queueRpcResponse('place_pharmacy_order', fakeSupabaseError('Not enough stock', { code: 'P0001' }));

    await expect(placePharmacyOrder(request, client as unknown as PharmacyOrderSource)).rejects.toEqual(
      expect.objectContaining({ code: 'P0001' }),
    );
  });
});
