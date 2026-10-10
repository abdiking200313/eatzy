/**
 * `fetchActivities` has no dedicated Flutter test file either (same as
 * `activity-item.test.ts`'s note) -- a new, focused test exercising it
 * against `src/test-utils/fake-supabase-client.ts` plus a plain `auth`
 * stub (the fake has no `auth` namespace of its own).
 */
import { createFakeSupabaseClient, fakeSupabaseError, fakeSupabaseOk } from '@/test-utils/fake-supabase-client';

import { fetchActivities, InvalidActivityLimitError, type ActivitySource } from './activity-repository';

// `activity-repository.ts` imports the real `@/platform/supabase/client`
// for its default `client` parameter, used only when a test doesn't inject
// its own (every test below does) -- see merchant-role-service.test.ts's
// own comment for why that import needs stubbing under Jest.
jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

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
