/**
 * Ports flutter_app/test/food_order_request_test.dart (issue #387 / P6-06).
 *
 * Ported: the `FoodOrderRequest.toRpcParams` group (all three cases).
 * Not duplicated here: the `describeOrderSaveError` group -- already
 * ported verbatim in `src/platform/orders/order-errors.test.ts` (#378).
 * Likewise flutter_app/test/placed_order_test.dart is already ported in
 * full in `src/platform/orders/placed-order.test.ts` (#378); the
 * `placeFoodOrder` cases below cover parsing a `place_food_order` response
 * through it end to end.
 *
 * Extra RN-only cases cover `placeFoodOrder` against the fake Supabase
 * client: the exact RPC name/params (ids + quantities + idempotency key,
 * no client-computed prices), response parsing, and error propagation.
 * Whether a real order lands in the database with server-computed prices
 * cannot be verified from a unit test; these stand in for that.
 */
import { createFakeSupabaseClient, fakeSupabaseError, fakeSupabaseOk } from '@/test-utils/fake-supabase-client';

import {
  foodOrderRequestToRpcParams,
  placeFoodOrder,
  type FoodOrderLineInput,
  type FoodOrderSource,
} from './food-order-repository';

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

const validItems: FoodOrderLineInput[] = [{ menuItemId: 'menu-1', quantity: 2 }];

describe('foodOrderRequestToRpcParams', () => {
  it('sends the trimmed delivery note as the street and leaves name, phone, district and city blank for the server to fill', () => {
    const params = foodOrderRequestToRpcParams({
      restaurantId: 'restaurant-1',
      delivery: { note: '  Near the mosque, blue gate  ' },
      items: validItems,
    });

    expect(params.p_restaurant_id).toBe('restaurant-1');
    expect(params.p_recipient_name).toBe('');
    expect(params.p_phone).toBe('');
    expect(params.p_street).toBe('Near the mosque, blue gate');
    expect(params.p_district).toBe('');
    expect(params.p_city).toBe('');
    expect(params.p_items).toEqual([{ menu_item_id: 'menu-1', quantity: 2 }]);
  });

  it('the delivery note is optional', () => {
    const params = foodOrderRequestToRpcParams({ restaurantId: 'restaurant-1', items: validItems });

    expect(params.p_street).toBe('');
  });

  it('still rejects an empty item list', () => {
    expect(() => foodOrderRequestToRpcParams({ restaurantId: 'restaurant-1', items: [] })).toThrow();
  });

  it('rejects a blank restaurant id, a blank menu item id, and a non-positive quantity', () => {
    expect(() => foodOrderRequestToRpcParams({ restaurantId: '  ', items: validItems })).toThrow();
    expect(() =>
      foodOrderRequestToRpcParams({ restaurantId: 'restaurant-1', items: [{ menuItemId: ' ', quantity: 1 }] }),
    ).toThrow();
    expect(() =>
      foodOrderRequestToRpcParams({ restaurantId: 'restaurant-1', items: [{ menuItemId: 'menu-1', quantity: 0 }] }),
    ).toThrow();
  });

  it('forwards the idempotency key, defaulting to null', () => {
    expect(foodOrderRequestToRpcParams({ restaurantId: 'r', items: validItems }).p_idempotency_key).toBeNull();
    expect(
      foodOrderRequestToRpcParams({ restaurantId: 'r', items: validItems, idempotencyKey: 'key-1' }).p_idempotency_key,
    ).toBe('key-1');
  });
});

describe('placeFoodOrder', () => {
  it('calls place_food_order with ids, quantities and the idempotency key only, and returns the server-computed totals', async () => {
    const client = createFakeSupabaseClient();
    client.queueRpcResponse(
      'place_food_order',
      fakeSupabaseOk([{ order_id: 'order-123', subtotal: 2000, delivery_fee: 499, tax: 200, total: 2699 }]),
    );

    const order = await placeFoodOrder(
      { restaurantId: 'restaurant-1', items: validItems, delivery: { note: 'Blue gate' }, idempotencyKey: 'key-1' },
      client as unknown as FoodOrderSource,
    );

    expect(order).toEqual({ orderId: 'order-123', subtotal: 2000, deliveryFee: 499, tax: 200, total: 2699 });
    expect(client.calls).toHaveLength(1);
    const call = client.calls[0];
    expect(call.kind).toBe('rpc');
    expect(call.name).toBe('place_food_order');
    expect(call.kind === 'rpc' && call.params).toEqual({
      p_restaurant_id: 'restaurant-1',
      p_recipient_name: '',
      p_phone: '',
      p_street: 'Blue gate',
      p_district: '',
      p_city: '',
      p_items: [{ menu_item_id: 'menu-1', quantity: 2 }],
      p_idempotency_key: 'key-1',
    });
  });

  it('rethrows the PostgREST error the RPC returns', async () => {
    const client = createFakeSupabaseClient();
    client.queueRpcResponse('place_food_order', fakeSupabaseError('Restaurant not found'));

    await expect(
      placeFoodOrder({ restaurantId: 'restaurant-1', items: validItems }, client as unknown as FoodOrderSource),
    ).rejects.toMatchObject({ message: 'Restaurant not found' });
  });

  it('rejects a response with no row', async () => {
    const client = createFakeSupabaseClient();
    client.queueRpcResponse('place_food_order', fakeSupabaseOk([]));

    await expect(
      placeFoodOrder({ restaurantId: 'restaurant-1', items: validItems }, client as unknown as FoodOrderSource),
    ).rejects.toThrow('The food order RPC did not return a row.');
  });
});
