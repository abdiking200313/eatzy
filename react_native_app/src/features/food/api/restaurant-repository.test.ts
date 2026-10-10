/**
 * `fetchRestaurants` has no dedicated Flutter test file (checked
 * `flutter_app/test/` directly) -- a new, focused test for this port's own
 * query-building contract, which is exactly what `food_home_screen_test.
 * dart`'s "tapping a category chip runs a real, server-side filter" case
 * exercises indirectly through a fake `restaurantQuery` callback: the two
 * query shapes (`menu_items!inner(categorie_id)` only added when a category
 * filter is active), the `ilike` search filter, and the default/custom
 * page-size `range` -- against `src/test-utils/fake-supabase-client.ts` the
 * same way `activity-repository.test.ts` tests `fetchActivities`.
 */
import { createFakeSupabaseClient, fakeSupabaseError, fakeSupabaseOk } from '@/test-utils/fake-supabase-client';

import { RESTAURANT_DEFAULT_PAGE_SIZE, fetchRestaurants, type RestaurantSource } from './restaurant-repository';

// `restaurant-repository.ts` imports the real `@/platform/supabase/client`
// for its default `client` parameter, used only when a test doesn't inject
// its own (every test below does) -- see merchant-role-service.test.ts's
// own comment for why that import needs stubbing under Jest.
jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

function fakeClient() {
  return createFakeSupabaseClient() as unknown as RestaurantSource & ReturnType<typeof createFakeSupabaseClient>;
}

function stepsOf(call: ReturnType<typeof createFakeSupabaseClient>['calls'][number]) {
  return call.kind === 'table' ? call.steps : [];
}

describe('fetchRestaurants', () => {
  it('with no filters, selects the plain columns and skips the menu_items join', async () => {
    const client = fakeClient();
    client.queueTableResponse('restaurants', fakeSupabaseOk([]));

    await fetchRestaurants({}, client);

    expect(client.calls).toEqual([
      {
        kind: 'table',
        name: 'restaurants',
        steps: [
          { method: 'select', args: ['id, name, description, logo_url'] },
          { method: 'order', args: ['name'] },
          { method: 'range', args: [0, RESTAURANT_DEFAULT_PAGE_SIZE - 1] },
        ],
      },
    ]);
  });

  it('applies a search filter via a case-insensitive ilike on name', async () => {
    const client = fakeClient();
    client.queueTableResponse('restaurants', fakeSupabaseOk([]));

    await fetchRestaurants({ searchQuery: 'kitchen' }, client);

    const steps = stepsOf(client.calls[0]);
    expect(steps).toEqual([
      { method: 'select', args: ['id, name, description, logo_url'] },
      { method: 'ilike', args: ['name', '%kitchen%'] },
      { method: 'order', args: ['name'] },
      { method: 'range', args: [0, RESTAURANT_DEFAULT_PAGE_SIZE - 1] },
    ]);
  });

  it('trims the search query before matching', async () => {
    const client = fakeClient();
    client.queueTableResponse('restaurants', fakeSupabaseOk([]));

    await fetchRestaurants({ searchQuery: '  kitchen  ' }, client);

    const steps = stepsOf(client.calls[0]);
    expect(steps.find((step) => step.method === 'ilike')?.args).toEqual(['name', '%kitchen%']);
  });

  it('treats a blank/whitespace-only search query as "no filter"', async () => {
    const client = fakeClient();
    client.queueTableResponse('restaurants', fakeSupabaseOk([]));

    await fetchRestaurants({ searchQuery: '   ' }, client);

    const steps = stepsOf(client.calls[0]);
    expect(steps.some((step) => step.method === 'ilike')).toBe(false);
  });

  it('applies a category filter via an inner join plus eq on menu_items.categorie_id', async () => {
    const client = fakeClient();
    client.queueTableResponse('restaurants', fakeSupabaseOk([]));

    await fetchRestaurants({ categoryId: 'rice' }, client);

    const steps = stepsOf(client.calls[0]);
    expect(steps).toEqual([
      { method: 'select', args: ['id, name, description, logo_url, menu_items!inner(categorie_id)'] },
      { method: 'eq', args: ['menu_items.categorie_id', 'rice'] },
      { method: 'order', args: ['name'] },
      { method: 'range', args: [0, RESTAURANT_DEFAULT_PAGE_SIZE - 1] },
    ]);
  });

  it('treats a blank categoryId as "no filter"', async () => {
    const client = fakeClient();
    client.queueTableResponse('restaurants', fakeSupabaseOk([]));

    await fetchRestaurants({ categoryId: '' }, client);

    const steps = stepsOf(client.calls[0]);
    expect(steps.some((step) => step.method === 'eq')).toBe(false);
    expect(steps[0].args).toEqual(['id, name, description, logo_url']);
  });

  it('combines a search query and a category filter in one call', async () => {
    const client = fakeClient();
    client.queueTableResponse('restaurants', fakeSupabaseOk([]));

    await fetchRestaurants({ searchQuery: 'kitchen', categoryId: 'rice' }, client);

    const steps = stepsOf(client.calls[0]);
    expect(steps).toEqual([
      { method: 'select', args: ['id, name, description, logo_url, menu_items!inner(categorie_id)'] },
      { method: 'eq', args: ['menu_items.categorie_id', 'rice'] },
      { method: 'ilike', args: ['name', '%kitchen%'] },
      { method: 'order', args: ['name'] },
      { method: 'range', args: [0, RESTAURANT_DEFAULT_PAGE_SIZE - 1] },
    ]);
  });

  it('applies a custom limit/offset to the range call', async () => {
    const client = fakeClient();
    client.queueTableResponse('restaurants', fakeSupabaseOk([]));

    await fetchRestaurants({ limit: 10, offset: 20 }, client);

    const steps = stepsOf(client.calls[0]);
    expect(steps.find((step) => step.method === 'range')?.args).toEqual([20, 29]);
  });

  it('maps rows through restaurantFromRow, including its fallbacks', async () => {
    const client = fakeClient();
    client.queueTableResponse(
      'restaurants',
      fakeSupabaseOk([
        { id: 'restaurant-1', name: 'Mogadishu Kitchen', description: 'Somali favourites', logo_url: 'https://example.com/logo.png' },
        { id: 'restaurant-2', name: null, description: null, logo_url: null },
      ]),
    );

    const restaurants = await fetchRestaurants({}, client);

    expect(restaurants).toEqual([
      { id: 'restaurant-1', name: 'Mogadishu Kitchen', description: 'Somali favourites', logoUrl: 'https://example.com/logo.png' },
      { id: 'restaurant-2', name: 'Unknown', description: '', logoUrl: '' },
    ]);
  });

  it('returns an empty list when data is null', async () => {
    const client = fakeClient();
    client.queueTableResponse('restaurants', fakeSupabaseOk(null));

    await expect(fetchRestaurants({}, client)).resolves.toEqual([]);
  });

  it('propagates a query error', async () => {
    const client = fakeClient();
    client.queueTableResponse('restaurants', fakeSupabaseError('offline'));

    await expect(fetchRestaurants({}, client)).rejects.toMatchObject({ message: 'offline' });
  });
});
