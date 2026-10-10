/**
 * `useRestaurantMenu`/`prefetchRestaurantMenu` have no dedicated Flutter
 * test file of their own (the Dart `CatalogQueries.restaurantMenu` cache
 * wrapper has no direct unit test either) -- a new, focused test for this
 * hook's own contract, modeled on `use-food-home.test.tsx`: the mapped
 * `RestaurantMenu` shape, "cached data wins" over a failed background
 * refetch (relevant here even at this hook's `staleTime: 0`, since that
 * only controls *when* a background refetch runs, not what happens to
 * `data` if it fails), and that a blank `restaurantId` never fires a query
 * at all (`enabled: restaurantId.length > 0`).
 *
 * `@/platform/supabase/client` is mocked with a `FakeSupabaseClient` (see
 * that file's own top comment) -- `restaurant-menu-repository.ts` falls
 * back to the real `supabase` import when `useRestaurantMenu` calls
 * `fetchMenu(restaurantId)` with no injected client, same as the real hook
 * does.
 */
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { renderHook, waitFor } from '@testing-library/react-native';
import type { ReactNode } from 'react';

import { queryClient as sharedQueryClient } from '@/platform/query/query-client';
import { supabase } from '@/platform/supabase/client';
import { createFakeSupabaseClient, fakeSupabaseError, fakeSupabaseOk } from '@/test-utils/fake-supabase-client';

import { prefetchRestaurantMenu, restaurantMenuQueryKey, useRestaurantMenu } from './use-restaurant-menu';

// `jest.mock` factories are hoisted above every import in this file, so a
// module-scoped helper (the `createFakeSupabaseClient` import above) isn't
// reachable from inside one -- this has to require() lazily inside the
// factory instead, same pattern as `use-food-home.test.tsx`.
jest.mock('@/platform/supabase/client', () => ({
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  supabase: require('@/test-utils/fake-supabase-client').createFakeSupabaseClient(),
}));

const fakeClient = supabase as unknown as ReturnType<typeof createFakeSupabaseClient>;

const sampleRestaurantRow = { id: 'restaurant-1', name: 'Test Kitchen', description: 'Fresh food made daily', logo_url: '' };
const sampleMenuItemRow = {
  id: 'burger-1',
  name: 'Classic Burger',
  description: 'Beef, cheese, and house sauce',
  price: 550,
  image_url: '',
  categorie_id: 'burgers',
  item_categories: { id: 'burgers', name: 'Burgers' },
};

function queueMenuSuccess() {
  fakeClient.queueTableResponse('restaurants', fakeSupabaseOk(sampleRestaurantRow));
  fakeClient.queueTableResponse('menu_items', fakeSupabaseOk([sampleMenuItemRow]));
}

const expectedMenu = {
  restaurant: { id: 'restaurant-1', name: 'Test Kitchen', description: 'Fresh food made daily', logoUrl: '' },
  categories: [
    {
      id: 'burgers',
      name: 'Burgers',
      items: [{ id: 'burger-1', name: 'Classic Burger', description: 'Beef, cheese, and house sauce', price: 550, imageUrl: '', categoryId: 'burgers' }],
    },
  ],
};

// Every per-test `QueryClient` created below, so `afterEach` can `clear()`
// each one -- otherwise each client's default `gcTime` leaves a pending
// cache-eviction timer behind, and Jest reports "did not exit" for a
// leaked timer (same reasoning as `use-food-home.test.tsx`'s own comment).
const testQueryClients: QueryClient[] = [];

function createTestQueryClient(): QueryClient {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  testQueryClients.push(client);
  return client;
}

function wrapperFor(client: QueryClient) {
  return function Wrapper({ children }: { children: ReactNode }) {
    return <QueryClientProvider client={client}>{children}</QueryClientProvider>;
  };
}

// `prefetchRestaurantMenu` warms the real app-wide singleton -- clear its
// cache so this file's own use of the `['catalog', 'restaurant-menu', id]`
// key doesn't bleed into (or out of) any other suite that touches the same
// singleton.
beforeEach(() => {
  sharedQueryClient.clear();
});

afterEach(() => {
  testQueryClients.splice(0).forEach((client) => client.clear());
});

afterAll(() => {
  sharedQueryClient.clear();
});

describe('useRestaurantMenu', () => {
  it("loads one restaurant's menu, grouped by category", async () => {
    queueMenuSuccess();
    const client = createTestQueryClient();

    const { result } = await renderHook(() => useRestaurantMenu('restaurant-1'), { wrapper: wrapperFor(client) });

    await waitFor(() => expect(result.current.data).toBeDefined());

    expect(result.current.data).toEqual(expectedMenu);
  });

  it('surfaces isError, with no data, on a first load that fails', async () => {
    fakeClient.queueTableResponse('restaurants', fakeSupabaseError('offline'));
    fakeClient.queueTableResponse('menu_items', fakeSupabaseOk([]));
    const client = createTestQueryClient();

    const { result } = await renderHook(() => useRestaurantMenu('restaurant-1'), { wrapper: wrapperFor(client) });

    await waitFor(() => expect(result.current.isError).toBe(true));
    expect(result.current.data).toBeUndefined();
  });

  it('keeps the last-loaded menu even after a background refetch fails ("cached data wins")', async () => {
    queueMenuSuccess();
    const client = createTestQueryClient();

    const { result } = await renderHook(() => useRestaurantMenu('restaurant-1'), { wrapper: wrapperFor(client) });
    await waitFor(() => expect(result.current.data).toBeDefined());
    const firstLoadData = result.current.data;

    // The next background refetch fails for both tables. `staleTime: 0`
    // (this hook always revalidates, see use-restaurant-menu.ts's top
    // comment) means this would happen automatically on the next mount/
    // focus too -- `refetch()` here just triggers it deterministically.
    fakeClient.queueTableResponse('restaurants', fakeSupabaseError('offline'));
    fakeClient.queueTableResponse('menu_items', fakeSupabaseError('offline'));
    await result.current.refetch();

    // Asserted straight off the `QueryClient`'s own cache state, same
    // reasoning as `use-food-home.test.tsx`'s own "cached data wins" case.
    const queryState = client.getQueryState(restaurantMenuQueryKey('restaurant-1'));
    expect(queryState?.status).toBe('error');
    expect(queryState?.data).toEqual(firstLoadData);
    expect(result.current.data).toEqual(firstLoadData);
  });

  it('never fires a query for a blank restaurantId', async () => {
    const client = createTestQueryClient();
    const callsBefore = fakeClient.calls.length;

    const { result } = await renderHook(() => useRestaurantMenu(''), { wrapper: wrapperFor(client) });

    expect(result.current.fetchStatus).toBe('idle');
    expect(result.current.data).toBeUndefined();
    expect(fakeClient.calls.length).toBe(callsBefore);
  });
});

describe('prefetchRestaurantMenu', () => {
  it('warms the shared queryClient cache under restaurantMenuQueryKey(restaurantId)', async () => {
    queueMenuSuccess();

    await prefetchRestaurantMenu('restaurant-1');

    expect(sharedQueryClient.getQueryData(restaurantMenuQueryKey('restaurant-1'))).toEqual(expectedMenu);
  });
});
