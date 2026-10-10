/**
 * `fetchCategories` has no dedicated Flutter test file (checked
 * `flutter_app/test/` directly) -- a new, focused test for this port's own
 * query-building contract: the fixed `item_categories` select/order shape
 * and the default/custom page-size `range`, against `src/test-utils/
 * fake-supabase-client.ts` the same way `activity-repository.test.ts` tests
 * `fetchActivities`.
 */
import { createFakeSupabaseClient, fakeSupabaseError, fakeSupabaseOk } from '@/test-utils/fake-supabase-client';

import { CATEGORY_DEFAULT_PAGE_SIZE, fetchCategories, type CategorySource } from './category-repository';

// `category-repository.ts` imports the real `@/platform/supabase/client`
// for its default `client` parameter, used only when a test doesn't inject
// its own (every test below does) -- see merchant-role-service.test.ts's
// own comment for why that import needs stubbing under Jest.
jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

function fakeClient() {
  return createFakeSupabaseClient() as unknown as CategorySource & ReturnType<typeof createFakeSupabaseClient>;
}

describe('fetchCategories', () => {
  it('selects id/name/icon_url ordered by name', async () => {
    const client = fakeClient();
    client.queueTableResponse('item_categories', fakeSupabaseOk([]));

    await fetchCategories({}, client);

    expect(client.calls).toEqual([
      {
        kind: 'table',
        name: 'item_categories',
        steps: [
          { method: 'select', args: ['id, name, icon_url'] },
          { method: 'order', args: ['name'] },
          { method: 'range', args: [0, CATEGORY_DEFAULT_PAGE_SIZE - 1] },
        ],
      },
    ]);
  });

  it('defaults to CATEGORY_DEFAULT_PAGE_SIZE when no limit/offset is given', async () => {
    const client = fakeClient();
    client.queueTableResponse('item_categories', fakeSupabaseOk([]));

    await fetchCategories({}, client);

    const call = client.calls[0];
    const rangeStep = call.kind === 'table' ? call.steps.find((step) => step.method === 'range') : undefined;
    expect(rangeStep?.args).toEqual([0, CATEGORY_DEFAULT_PAGE_SIZE - 1]);
  });

  it('applies a custom limit/offset to the range call', async () => {
    const client = fakeClient();
    client.queueTableResponse('item_categories', fakeSupabaseOk([]));

    await fetchCategories({ limit: 10, offset: 20 }, client);

    const call = client.calls[0];
    const rangeStep = call.kind === 'table' ? call.steps.find((step) => step.method === 'range') : undefined;
    expect(rangeStep?.args).toEqual([20, 29]);
  });

  it('maps rows through categoryFromRow, including its fallbacks', async () => {
    const client = fakeClient();
    client.queueTableResponse(
      'item_categories',
      fakeSupabaseOk([
        { id: 'rice', name: 'Rice', icon_url: 'https://example.com/rice.png' },
        { id: 'grill', name: null, icon_url: null },
      ]),
    );

    const categories = await fetchCategories({}, client);

    expect(categories).toEqual([
      { id: 'rice', name: 'Rice', iconUrl: 'https://example.com/rice.png' },
      { id: 'grill', name: 'Unknown', iconUrl: '' },
    ]);
  });

  it('returns an empty list when data is null', async () => {
    const client = fakeClient();
    client.queueTableResponse('item_categories', fakeSupabaseOk(null));

    await expect(fetchCategories({}, client)).resolves.toEqual([]);
  });

  it('propagates a query error', async () => {
    const client = fakeClient();
    client.queueTableResponse('item_categories', fakeSupabaseError('offline'));

    await expect(fetchCategories({}, client)).rejects.toMatchObject({ message: 'offline' });
  });
});
