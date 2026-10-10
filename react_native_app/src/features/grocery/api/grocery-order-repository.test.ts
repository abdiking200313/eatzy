/**
 * Covers `grocery-order-repository.ts` (issue #392 / P7-04): the
 * `GroceryOrderRequest.toRpcParams`/`GroceryOrderLineInput.toRpcMap`
 * validation, `GroceryDeliverySlot.fromMap`, and the two Supabase calls
 * (`grocery_delivery_slots_available`, `place_grocery_order`) against the
 * fake Supabase client. Flutter has no dedicated test file for these; the
 * request-shape assertions mirror `food-order-repository.test.ts`.
 *
 * Whether an order really lands in the database cannot be verified from a
 * unit test (no live database); the exact RPC name/params asserted here
 * stand in for that.
 */
import { createFakeSupabaseClient, fakeSupabaseError, fakeSupabaseOk } from '@/test-utils/fake-supabase-client';

import {
  fetchGroceryDeliverySlots,
  groceryDeliverySlotFromRow,
  groceryOrderRequestToRpcParams,
  grocerySubstitutionDescription,
  grocerySubstitutionLabel,
  placeGroceryOrder,
  type GroceryDeliverySlotSource,
  type GroceryOrderRequest,
  type GroceryOrderSource,
} from './grocery-order-repository';

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

const request: GroceryOrderRequest = {
  storeId: 'bakaal-fresh',
  deliverySlotId: 'slot-1',
  substitutionPreference: 'contactMe',
  delivery: { note: '  Near Taleex Road  ' },
  items: [
    { productId: 'bakaal-rice', quantity: 2 },
    { productId: 'bakaal-bananas', quantity: 1.5 },
  ],
  idempotencyKey: 'attempt-1',
};

describe('groceryOrderRequestToRpcParams', () => {
  it('sends ids, quantities, the slot, the substitution preference and the idempotency key -- never a price', () => {
    expect(groceryOrderRequestToRpcParams(request)).toEqual({
      p_store_id: 'bakaal-fresh',
      p_delivery_slot_id: 'slot-1',
      p_recipient_name: '',
      p_phone: '',
      p_street: 'Near Taleex Road',
      p_district: '',
      p_city: '',
      p_substitution_preference: 'contact_me',
      p_items: [
        { product_id: 'bakaal-rice', quantity: 2 },
        { product_id: 'bakaal-bananas', quantity: 1.5 },
      ],
      p_idempotency_key: 'attempt-1',
    });
  });

  it('maps every substitution preference to its database value', () => {
    expect(groceryOrderRequestToRpcParams({ ...request, substitutionPreference: 'bestMatch' }).p_substitution_preference).toBe(
      'best_match',
    );
    expect(
      groceryOrderRequestToRpcParams({ ...request, substitutionPreference: 'noSubstitutions' }).p_substitution_preference,
    ).toBe('no_substitutions');
  });

  it('defaults the delivery note to empty and the idempotency key to null', () => {
    const params = groceryOrderRequestToRpcParams({ ...request, delivery: undefined, idempotencyKey: undefined });
    expect(params.p_street).toBe('');
    expect(params.p_idempotency_key).toBeNull();
  });

  it('rejects a blank store or slot, no items, a blank product id, and a non-positive quantity', () => {
    expect(() => groceryOrderRequestToRpcParams({ ...request, storeId: ' ' })).toThrow('Store and delivery slot are required.');
    expect(() => groceryOrderRequestToRpcParams({ ...request, deliverySlotId: '' })).toThrow(
      'Store and delivery slot are required.',
    );
    expect(() => groceryOrderRequestToRpcParams({ ...request, items: [] })).toThrow('A grocery order requires at least one item.');
    expect(() => groceryOrderRequestToRpcParams({ ...request, items: [{ productId: ' ', quantity: 1 }] })).toThrow(
      'A grocery product ID is required.',
    );
    expect(() => groceryOrderRequestToRpcParams({ ...request, items: [{ productId: 'x', quantity: 0 }] })).toThrow(
      'Grocery quantity must be positive.',
    );
    expect(() => groceryOrderRequestToRpcParams({ ...request, items: [{ productId: 'x', quantity: Number.NaN }] })).toThrow(
      'Grocery quantity must be positive.',
    );
  });
});

describe('substitution preference copy', () => {
  it('matches the Flutter labels and descriptions', () => {
    expect(grocerySubstitutionLabel('bestMatch')).toBe('Choose the best match');
    expect(grocerySubstitutionLabel('contactMe')).toBe('Contact me first');
    expect(grocerySubstitutionLabel('noSubstitutions')).toBe('No substitutions');
    expect(grocerySubstitutionDescription('bestMatch')).toBe('Replace unavailable items with a similar product.');
    expect(grocerySubstitutionDescription('contactMe')).toBe('Ask before replacing an unavailable item.');
    expect(grocerySubstitutionDescription('noSubstitutions')).toBe('Refund any item that becomes unavailable.');
  });
});

describe('groceryDeliverySlotFromRow', () => {
  it('parses a row and rejects one missing a required field', () => {
    expect(groceryDeliverySlotFromRow({ id: 's1', store_id: 'store', label: ' Today ', detail: '2:00 PM – 4:00 PM' })).toEqual({
      id: 's1',
      storeId: 'store',
      label: 'Today',
      detail: '2:00 PM – 4:00 PM',
    });
    expect(() => groceryDeliverySlotFromRow({ id: 's1', store_id: 'store', label: '', detail: 'x' })).toThrow(
      'Missing required grocery field: label',
    );
  });
});

describe('fetchGroceryDeliverySlots', () => {
  it('reads the available-slots view for one store, in sort order', async () => {
    const client = createFakeSupabaseClient();
    client.queueTableResponse(
      'grocery_delivery_slots_available',
      fakeSupabaseOk([{ id: 's1', store_id: 'bakaal-fresh', label: 'Today', detail: '6:00 PM – 8:00 PM' }]),
    );

    const slots = await fetchGroceryDeliverySlots('bakaal-fresh', client as unknown as GroceryDeliverySlotSource);

    expect(slots).toEqual([{ id: 's1', storeId: 'bakaal-fresh', label: 'Today', detail: '6:00 PM – 8:00 PM' }]);
    expect(client.calls[0]).toEqual({
      kind: 'table',
      name: 'grocery_delivery_slots_available',
      steps: [
        { method: 'select', args: ['id, store_id, label, detail'] },
        { method: 'eq', args: ['store_id', 'bakaal-fresh'] },
        { method: 'order', args: ['sort_order'] },
      ],
    });
  });

  it('rejects a blank store id and propagates a query error', async () => {
    const client = createFakeSupabaseClient();
    await expect(fetchGroceryDeliverySlots(' ', client as unknown as GroceryDeliverySlotSource)).rejects.toThrow(
      'A grocery store ID is required.',
    );

    client.queueTableResponse('grocery_delivery_slots_available', fakeSupabaseError('boom'));
    await expect(fetchGroceryDeliverySlots('bakaal-fresh', client as unknown as GroceryDeliverySlotSource)).rejects.toEqual(
      expect.objectContaining({ message: 'boom' }),
    );
  });
});

describe('placeGroceryOrder', () => {
  it('calls place_grocery_order and returns the server-computed totals', async () => {
    const client = createFakeSupabaseClient();
    client.queueRpcResponse(
      'place_grocery_order',
      fakeSupabaseOk([{ order_id: 'grocery-order-1', subtotal: 1000, delivery_fee: 250, tax: 0, total: 1250 }]),
    );

    const placed = await placeGroceryOrder(request, client as unknown as GroceryOrderSource);

    expect(placed).toEqual({ orderId: 'grocery-order-1', subtotal: 1000, deliveryFee: 250, tax: 0, total: 1250 });
    expect(client.calls[0]).toEqual(
      expect.objectContaining({ kind: 'rpc', name: 'place_grocery_order', params: groceryOrderRequestToRpcParams(request) }),
    );
  });

  it('rethrows the RPC error as-is (e.g. an elapsed delivery window)', async () => {
    const client = createFakeSupabaseClient();
    client.queueRpcResponse(
      'place_grocery_order',
      fakeSupabaseError('The selected delivery window has already passed. Please choose another delivery slot.', {
        code: 'P0001',
      }),
    );

    await expect(placeGroceryOrder(request, client as unknown as GroceryOrderSource)).rejects.toEqual(
      expect.objectContaining({ code: 'P0001' }),
    );
  });
});
