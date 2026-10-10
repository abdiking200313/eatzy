/**
 * Exercises `activity-repository.ts` against
 * `src/test-utils/fake-supabase-client.ts` plus a plain `auth` stub (the
 * fake has no `auth` namespace of its own). Issue #397 / P8-01 ports the
 * cases of `flutter_app/test/activity_repository_test.dart` here
 * (malformed rows skipped, all-malformed -> empty, and the
 * `fetchOrderById` group), plus `fetchOrderDetails` and the two Realtime
 * helpers against a fake channel.
 */
import { ErrorReporting, NoopErrorReporter, type ErrorReporter } from '@/platform/error-reporting/error-reporter';
import { createFakeSupabaseClient, fakeSupabaseError, fakeSupabaseOk } from '@/test-utils/fake-supabase-client';

import {
  fetchActivities,
  fetchOrderById,
  fetchOrderDetails,
  InvalidActivityLimitError,
  watchCustomerOrders,
  watchOrder,
  type ActivitySource,
  type OrderChangePayload,
  type OrderDetailsSource,
  type RealtimeChannelLike,
  type RealtimeSource,
} from './activity-repository';
import { paymentMethodLabel, paymentStatusLabel } from './activity-item';

// `activity-repository.ts` imports the real `@/platform/supabase/client`
// for its default `client` parameter, used only when a test doesn't inject
// its own (every test below does) -- see merchant-role-service.test.ts's
// own comment for why that import needs stubbing under Jest.
jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

// Malformed-row cases report through ErrorReporting; keep that out of the test output.
let originalReporter: ErrorReporter;
beforeEach(() => {
  originalReporter = ErrorReporting.instance;
  ErrorReporting.instance = new NoopErrorReporter();
});
afterEach(() => {
  ErrorReporting.instance = originalReporter;
});

function withAuth(userId: string | null) {
  const fake = createFakeSupabaseClient();
  return Object.assign(fake, {
    auth: {
      getSession: async () => ({ data: { session: userId ? { user: { id: userId } } : null } }),
    },
  }) as unknown as ActivitySource & { queueTableResponse: typeof fake.queueTableResponse; calls: typeof fake.calls };
}

const validRow = {
  id: 'order-1',
  profile_id: 'user-1',
  service_id: 'grocery',
  title: 'Bakaara groceries',
  subtitle: 'Bakaara Mart',
  status: 'Confirmed',
  occurred_at: '2026-07-27T00:00:00.000Z',
  amount: 2400,
  details_route: '/grocery',
  payment_method: 'cash_on_delivery',
  payment_status: 'pending_collection',
};

describe('fetchActivities', () => {
  it('throws when no one is signed in', async () => {
    const client = withAuth(null);

    await expect(fetchActivities(client)).rejects.toThrow('Sign in before loading customer activity.');
  });

  it('rejects a limit outside 1-100', async () => {
    const client = withAuth('user-1');

    await expect(fetchActivities(client, 0)).rejects.toBeInstanceOf(InvalidActivityLimitError);
    await expect(fetchActivities(client, 101)).rejects.toBeInstanceOf(InvalidActivityLimitError);
  });

  it('returns parsed items for the signed-in profile, most recent first', async () => {
    const client = withAuth('user-1');
    client.queueTableResponse('customer_activity', fakeSupabaseOk([validRow]));

    const items = await fetchActivities(client);

    expect(items).toHaveLength(1);
    expect(items[0]).toMatchObject({ id: 'order-1', title: 'Bakaara groceries', amount: 2400 });
    expect(client.calls[0]).toMatchObject({ kind: 'table', name: 'customer_activity' });
  });

  it('skips a malformed row instead of failing the whole fetch', async () => {
    const client = withAuth('user-1');
    client.queueTableResponse('customer_activity', fakeSupabaseOk([validRow, { ...validRow, id: 'order-2', title: undefined }]));

    const items = await fetchActivities(client);

    expect(items).toHaveLength(1);
    expect(items[0].id).toBe('order-1');
  });

  it('propagates a query error', async () => {
    const client = withAuth('user-1');
    client.queueTableResponse('customer_activity', fakeSupabaseError('offline'));

    await expect(fetchActivities(client)).rejects.toMatchObject({ message: 'offline' });
  });
});

describe('fetchActivities (ports activity_repository_test.dart)', () => {
  it('returns an empty list (not an error) when every row is malformed', async () => {
    const client = withAuth('user-1');
    client.queueTableResponse('customer_activity', fakeSupabaseOk([{ ...validRow, id: 'bad-1', title: '' }]));

    await expect(fetchActivities(client)).resolves.toEqual([]);
  });
});

const orderRow = {
  id: 'order-1',
  profile_id: 'user-1',
  service_id: 'food',
  title: 'Jollof Feast Order',
  subtitle: null,
  status: 'On the way',
  occurred_at: '2026-08-01T00:00:00.000Z',
  amount: 1850,
  details_route: '/food',
  payment_method: 'cash_on_delivery',
  payment_status: 'pending_collection',
};

function detailsClient(userId: string | null) {
  return withAuth(userId) as unknown as OrderDetailsSource & ReturnType<typeof withAuth>;
}

describe('fetchOrderById (ports activity_repository_test.dart, issue #43)', () => {
  it('returns the matching order when the view has exactly one row', async () => {
    const client = detailsClient('user-1');
    client.queueTableResponse('customer_activity', fakeSupabaseOk(orderRow));

    const order = await fetchOrderById({ orderId: 'order-1', serviceId: 'food' }, client);

    expect(order).not.toBeNull();
    expect(order!.id).toBe('order-1');
    expect(order!.title).toBe('Jollof Feast Order');
    expect(order!.status).toBe('On the way');
    expect(order!.paymentMethod).toBe('cash_on_delivery');
    expect(order!.paymentStatus).toBe('pending_collection');
    expect(paymentMethodLabel(order!)).toBe('Cash on delivery');
    expect(paymentStatusLabel(order!)).toBe('Pending collection');
    expect(client.calls[0].steps).toEqual(
      expect.arrayContaining([
        { method: 'eq', args: ['profile_id', 'user-1'] },
        { method: 'eq', args: ['id', 'order-1'] },
        { method: 'eq', args: ['service_id', 'food'] },
        { method: 'maybeSingle', args: [] },
      ]),
    );
  });

  it('leaves payment fields undefined for a row from before the payment columns existed', async () => {
    const client = detailsClient('user-1');
    const { payment_method: _method, payment_status: _status, ...legacyRow } = orderRow;
    client.queueTableResponse('customer_activity', fakeSupabaseOk(legacyRow));

    const order = await fetchOrderById({ orderId: 'order-1', serviceId: 'food' }, client);

    expect(order).not.toBeNull();
    expect(order!.paymentMethod).toBeUndefined();
    expect(order!.paymentStatus).toBeUndefined();
    expect(paymentMethodLabel(order!)).toBeUndefined();
    expect(paymentStatusLabel(order!)).toBeUndefined();
  });

  it('returns null when no row matches (not found, or RLS scoped it away)', async () => {
    const client = detailsClient('user-1');
    client.queueTableResponse('customer_activity', fakeSupabaseOk(null));

    await expect(fetchOrderById({ orderId: 'missing-order', serviceId: 'food' }, client)).resolves.toBeNull();
  });

  it('throws when no one is signed in, without querying', async () => {
    const client = detailsClient(null);

    await expect(fetchOrderById({ orderId: 'order-1', serviceId: 'food' }, client)).rejects.toThrow('Sign in before loading order details.');
    expect(client.calls).toHaveLength(0);
  });
});

describe('fetchOrderDetails', () => {
  it('reads the per-vertical order row with its lines, charges and address', async () => {
    const client = detailsClient('user-1');
    client.queueTableResponse('customer_activity', fakeSupabaseOk({ ...orderRow, service_id: 'grocery' }));
    client.queueTableResponse(
      'grocery_orders',
      fakeSupabaseOk({
        subtotal: 2400,
        delivery_fee: 300,
        total: 2700,
        recipient_name: 'Ayaan',
        phone: null,
        street: 'Maka Al Mukarama',
        district: '',
        city: 'Mogadishu',
        store_name: 'Bakaara Mart',
        delivery_slot_label: 'Today 5-6pm',
        grocery_order_items: [{ product_name: 'Rice', quantity: 1.5, unit_price: 1600, pricing_unit: 'kilogram' }],
      }),
    );

    const details = await fetchOrderDetails({ orderId: 'order-1', serviceId: 'grocery' }, client);

    expect(details).not.toBeNull();
    expect(details!.lines).toEqual([{ name: 'Rice', quantity: 1.5, unitPrice: 1600, pricingUnit: 'kilogram' }]);
    expect(details!.total).toBe(2700);
    expect(details!.tax).toBeUndefined();
    expect(details!.storeName).toBe('Bakaara Mart');
    expect(details!.deliveryNote).toBe('Today 5-6pm');
    expect(client.calls[1]).toMatchObject({ kind: 'table', name: 'grocery_orders' });
    expect(String(client.calls[1].steps[0].args[0])).toContain('grocery_order_items(product_name, quantity, unit_price, pricing_unit)');
  });

  it('returns null for an unknown service without querying an order table', async () => {
    const client = detailsClient('user-1');
    client.queueTableResponse('customer_activity', fakeSupabaseOk({ ...orderRow, service_id: 'laundry' }));

    await expect(fetchOrderDetails({ orderId: 'order-1', serviceId: 'laundry' }, client)).resolves.toBeNull();
    expect(client.calls).toHaveLength(1);
  });
});

/** A fake Realtime client recording every channel/listener and letting a test push a change. */
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

describe('watchCustomerOrders', () => {
  it("listens to every order table, filtered to the user's own orders, and reports the changed order", () => {
    const realtime = fakeRealtime();
    const changes: unknown[] = [];

    const stop = watchCustomerOrders('user-1', (change) => changes.push(change), realtime.client);

    expect(realtime.listeners.map((l) => [l.table, l.filter])).toEqual([
      ['food_orders', 'profile_id=eq.user-1'],
      ['grocery_orders', 'profile_id=eq.user-1'],
      ['pharmacy_orders', 'profile_id=eq.user-1'],
    ]);
    expect(realtime.subscribed).toEqual(['activity-feed:user-1']);

    realtime.listeners[1].callback({ new: { id: 'g-1', status: 'shopping' }, old: {} });
    realtime.listeners[0].callback({ new: {}, old: {} });
    expect(changes).toEqual([{ serviceId: 'grocery', orderId: 'g-1' }]);

    stop();
    stop();
    expect(realtime.removed).toEqual(['activity-feed:user-1']);
  });
});

describe('watchOrder', () => {
  it("watches only this order's own row and ticks on every change", () => {
    const realtime = fakeRealtime();
    const onChange = jest.fn();

    const stop = watchOrder({ orderId: 'order-1', serviceId: 'pharmacy' }, onChange, realtime.client);
    expect(realtime.listeners).toHaveLength(1);
    expect(realtime.listeners[0]).toMatchObject({ channel: 'order-watch:pharmacy_orders:order-1', table: 'pharmacy_orders', filter: 'id=eq.order-1' });

    realtime.listeners[0].callback({ new: { id: 'order-1' } });
    expect(onChange).toHaveBeenCalledTimes(1);

    stop();
    expect(realtime.removed).toEqual(['order-watch:pharmacy_orders:order-1']);
  });

  it('watches nothing for an unknown service', () => {
    const realtime = fakeRealtime();

    watchOrder({ orderId: 'order-1', serviceId: 'laundry' }, jest.fn(), realtime.client)();

    expect(realtime.listeners).toHaveLength(0);
    expect(realtime.removed).toHaveLength(0);
  });
});
