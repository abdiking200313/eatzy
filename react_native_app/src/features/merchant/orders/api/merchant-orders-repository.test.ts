/**
 * RN coverage for `SupabaseMerchantOrdersRepository` (issue #408 / P9-03).
 * Flutter has no repository-level test for this file; these pin the query
 * shape the Dart repository builds (per-vertical columns + embedded items,
 * store scoping, newest first, the 500-row bound), the RPC call and its
 * error mapping, and the RN-only realtime subscription.
 */
import type { OrderChangePayload, RealtimeChannelLike, RealtimeSource } from '@/platform/activity/api/activity-repository';
import { createFakeSupabaseClient, fakeSupabaseError, fakeSupabaseOk, type FakeSupabaseCall } from '@/test-utils/fake-supabase-client';

import {
  MAX_ORDERS_PER_STORE,
  merchantOrderSelection,
  SupabaseMerchantOrdersRepository,
  type MerchantOrdersSource,
} from './merchant-orders-repository';
import { OrderStatusTransitionError } from './order-status-transition-error';

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

function fakeRealtime() {
  const listeners: { channel: string; table: string; filter?: string; callback: (payload: OrderChangePayload) => void }[] = [];
  const removed: string[] = [];
  const subscribed: string[] = [];
  const client: RealtimeSource = {
    channel(name) {
      const channel: RealtimeChannelLike & { name: string } = {
        name,
        on(_type, filter, callback) {
          listeners.push({ channel: name, table: filter.table, filter: filter.filter, callback });
          return channel;
        },
        subscribe() {
          subscribed.push(name);
          return channel;
        },
      };
      return channel;
    },
    removeChannel(channel) {
      removed.push((channel as RealtimeChannelLike & { name: string }).name);
      return Promise.resolve('ok');
    },
  };
  return { client, listeners, removed, subscribed };
}

function setup() {
  const fake = createFakeSupabaseClient();
  const realtime = fakeRealtime();
  const repo = new SupabaseMerchantOrdersRepository(fake as unknown as MerchantOrdersSource, realtime.client);
  return { fake, realtime, repo };
}

function steps(call: FakeSupabaseCall, method: string): unknown[][] {
  return call.steps.filter((step) => step.method === method).map((step) => step.args);
}

describe('fetchOrders', () => {
  it('selects the food columns plus embedded items, scoped to the restaurant, newest first and bounded', async () => {
    const { fake, repo } = setup();
    fake.queueTableResponse(
      'food_orders',
      fakeSupabaseOk([{ id: 'o-1', status: 'preparing', total: 1599, food_order_items: [{ id: 1, item_name: 'Sambusa', quantity: 2, unit_price: 250 }] }]),
    );

    const orders = await repo.fetchOrders({ vertical: 'food', storeId: 'r-1' });

    expect(orders).toHaveLength(1);
    expect(orders[0]).toMatchObject({ id: 'o-1', status: 'preparing', totalCents: 1599 });
    expect(orders[0].items[0].name).toBe('Sambusa');
    const call = fake.calls[0];
    expect(call.name).toBe('food_orders');
    const selection = String(steps(call, 'select')[0][0]);
    expect(selection).toBe(merchantOrderSelection('food'));
    expect(selection).toContain('tax');
    expect(selection).toContain('food_order_items(id, item_name, quantity, unit_price)');
    expect(selection).not.toContain('delivery_slot_label');
    expect(steps(call, 'eq')).toEqual([['restaurant_id', 'r-1']]);
    expect(steps(call, 'order')).toEqual([['created_at', { ascending: false }]]);
    expect(steps(call, 'limit')).toEqual([[MAX_ORDERS_PER_STORE]]);
  });

  it('grocery filters on store_id and selects its slot/substitution columns', async () => {
    const { fake, repo } = setup();

    expect(await repo.fetchOrders({ vertical: 'grocery', storeId: 'g-1' })).toEqual([]);

    const call = fake.calls[0];
    expect(call.name).toBe('grocery_orders');
    const selection = String(steps(call, 'select')[0][0]);
    expect(selection).toContain('delivery_slot_label, substitution_preference');
    expect(selection).toContain('grocery_order_items(id, product_name, quantity, unit_price)');
    expect(selection).not.toMatch(/\btax\b/);
    expect(steps(call, 'eq')).toEqual([['store_id', 'g-1']]);
  });

  it('pharmacy has no store column, so it relies on RLS with no client-side filter', async () => {
    const { fake, repo } = setup();

    await repo.fetchOrders({ vertical: 'pharmacy', storeId: 'p-1' });

    const call = fake.calls[0];
    expect(call.name).toBe('pharmacy_orders');
    expect(String(steps(call, 'select')[0][0])).toContain('delivery_instructions');
    expect(steps(call, 'eq')).toEqual([]);
  });

  it('propagates a query error', async () => {
    const { fake, repo } = setup();
    fake.queueTableResponse('food_orders', fakeSupabaseError('permission denied'));

    await expect(repo.fetchOrders({ vertical: 'food', storeId: 'r-1' })).rejects.toMatchObject({ message: 'permission denied' });
  });
});

describe('advanceOrderStatus', () => {
  it('calls the vertical RPC and returns the server status', async () => {
    const { fake, repo } = setup();
    fake.queueRpcResponse('advance_grocery_order_status', fakeSupabaseOk('shopping'));

    expect(await repo.advanceOrderStatus({ vertical: 'grocery', orderId: 'o-1', newStatus: 'shopping' })).toBe('shopping');
    expect(fake.calls[0]).toMatchObject({
      kind: 'rpc',
      name: 'advance_grocery_order_status',
      params: { p_order_id: 'o-1', p_new_status: 'shopping' },
    });
  });

  it('falls back to the requested status when the RPC returns nothing', async () => {
    const { repo } = setup();
    expect(await repo.advanceOrderStatus({ vertical: 'food', orderId: 'o-1', newStatus: 'preparing' })).toBe('preparing');
  });

  it("maps an RPC rejection to OrderStatusTransitionError carrying the server's message", async () => {
    const { fake, repo } = setup();
    fake.queueRpcResponse('advance_food_order_status', fakeSupabaseError('Illegal food order status transition: confirmed -> delivered'));

    const promise = repo.advanceOrderStatus({ vertical: 'food', orderId: 'o-1', newStatus: 'delivered' });
    await expect(promise).rejects.toBeInstanceOf(OrderStatusTransitionError);
    await expect(promise).rejects.toThrow('Illegal food order status transition: confirmed -> delivered');
  });
});

describe('watchOrders (RN-only realtime)', () => {
  it("listens to the vertical's order table filtered to this store, and stops idempotently", () => {
    const { realtime, repo } = setup();
    const onChange = jest.fn();

    const stop = repo.watchOrders({ vertical: 'food', storeId: 'r-1' }, onChange);

    expect(realtime.listeners).toEqual([
      expect.objectContaining({ channel: 'merchant-orders:food_orders:r-1', table: 'food_orders', filter: 'restaurant_id=eq.r-1' }),
    ]);
    expect(realtime.subscribed).toEqual(['merchant-orders:food_orders:r-1']);

    realtime.listeners[0].callback({ new: { id: 'o-2', status: 'confirmed' } });
    expect(onChange).toHaveBeenCalledTimes(1);

    stop();
    stop();
    expect(realtime.removed).toEqual(['merchant-orders:food_orders:r-1']);
  });

  it('grocery filters on store_id; pharmacy subscribes unfiltered (RLS-scoped)', () => {
    const { realtime, repo } = setup();

    repo.watchOrders({ vertical: 'grocery', storeId: 'g-1' }, () => {});
    repo.watchOrders({ vertical: 'pharmacy', storeId: 'p-1' }, () => {});

    expect(realtime.listeners.map((l) => [l.table, l.filter])).toEqual([
      ['grocery_orders', 'store_id=eq.g-1'],
      ['pharmacy_orders', undefined],
    ]);
  });
});
