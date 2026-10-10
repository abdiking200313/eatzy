/**
 * `useFoodHome`/`prefetchFoodHome` have no dedicated Flutter test file of
 * their own -- `food_home_screen_test.dart`'s "food home coordinates
 * category and restaurant loading" case exercises the combined load
 * end-to-end through `FoodHomeScreen`'s injected `categoryLoader`/
 * `restaurantLoader` callbacks (ported at the screen layer, see `../../../
 * app/(app)/(tabs)/food/index.test.tsx`). This is a focused unit test for
 * this hook's own contract instead: the combined `{categories,
 * restaurants}` shape, and the "cached data always wins" behavior
 * `food/index.tsx`'s top comment documents -- a failed *background*
 * refetch flips the underlying query's `status` to `'error'` (confirmed by
 * reading `@tanstack/query-core`'s `Query#dispatch`: an "error" action
 * always sets `status: 'error'`, it does not special-case "but there was
 * already data"), but leaves `data` itself untouched. See the "cached data
 * wins" test below for why this is asserted off the `QueryClient`'s own
 * cache state rather than the hook's returned `isError`.
 *
 * `@/platform/supabase/client` is mocked with a `FakeSupabaseClient` (see
 * that file's own top comment) -- `category-repository.ts`/
 * `restaurant-repository.ts` fall back to the real `supabase` import when
 * `useFoodHome`'s `loadFoodHome` calls `fetchCategories()`/
 * `fetchRestaurants()` with no injected client, same as the real hook does.
 */
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { renderHook, waitFor } from '@testing-library/react-native';
import type { ReactNode } from 'react';

import { queryClient as sharedQueryClient } from '@/platform/query/query-client';
import { supabase } from '@/platform/supabase/client';
import { createFakeSupabaseClient, fakeSupabaseError, fakeSupabaseOk } from '@/test-utils/fake-supabase-client';

import { FOOD_HOME_QUERY_KEY, prefetchFoodHome, useFoodHome } from './use-food-home';

// `jest.mock` factories are hoisted above every import in this file, so a
// module-scoped helper (the `createFakeSupabaseClient` import above) isn't
// reachable from inside one -- this has to require() lazily inside the
// factory instead, same pattern as `service-pricing-repository.test.tsx`.
jest.mock('@/platform/supabase/client', () => ({
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  supabase: require('@/test-utils/fake-supabase-client').createFakeSupabaseClient(),
}));

const fakeClient = supabase as unknown as ReturnType<typeof createFakeSupabaseClient>;

const sampleCategoryRow = { id: 'rice', name: 'Rice', icon_url: '' };
const sampleRestaurantRow = { id: 'restaurant-1', name: 'Mogadishu Kitchen', description: 'Somali favourites', logo_url: '' };

function queueHomeSuccess() {
  fakeClient.queueTableResponse('item_categories', fakeSupabaseOk([sampleCategoryRow]));
  fakeClient.queueTableResponse('restaurants', fakeSupabaseOk([sampleRestaurantRow]));
}

// Every per-test `QueryClient` created below, so `afterEach` can `clear()`
// each one -- otherwise each client's default `gcTime` leaves a pending
// cache-eviction timer behind, and Jest reports "did not exit" for a
// leaked timer (same reasoning as `service-pricing-repository.test.tsx`'s
// own comment on why it clears the shared singleton in `afterAll`).
const testQueryClients: QueryClient[] = [];

/** A fresh, retry-disabled `QueryClient` per test -- `useFoodHome` reads context, not the app-wide singleton, so a local client keeps tests isolated from each other. */
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

// `prefetchFoodHome` warms the real app-wide singleton -- clear its cache so
// this file's own use of the `['catalog', 'food-home']` key doesn't bleed
// into (or out of) any other suite that touches the same singleton.
beforeEach(() => {
  sharedQueryClient.clear();
});

afterEach(() => {
  testQueryClients.splice(0).forEach((client) => client.clear());
});

afterAll(() => {
  sharedQueryClient.clear();
});

describe('useFoodHome', () => {
  it('loads categories and restaurants together into one FoodHomeData', async () => {
    queueHomeSuccess();
    const client = createTestQueryClient();

    const { result } = await renderHook(() => useFoodHome(), { wrapper: wrapperFor(client) });

    await waitFor(() => expect(result.current.data).toBeDefined());

    expect(result.current.data).toEqual({
      categories: [{ id: 'rice', name: 'Rice', iconUrl: '' }],
      restaurants: [{ id: 'restaurant-1', name: 'Mogadishu Kitchen', description: 'Somali favourites', logoUrl: '' }],
    });
  });

  it('surfaces isError, with no data, on a first load that fails', async () => {
    fakeClient.queueTableResponse('item_categories', fakeSupabaseError('offline'));
    fakeClient.queueTableResponse('restaurants', fakeSupabaseOk([sampleRestaurantRow]));
    const client = createTestQueryClient();

    const { result } = await renderHook(() => useFoodHome(), { wrapper: wrapperFor(client) });

    await waitFor(() => expect(result.current.isError).toBe(true));
    expect(result.current.data).toBeUndefined();
  });

  it('keeps the last-loaded data even after a background refetch fails ("cached data wins")', async () => {
    queueHomeSuccess();
    const client = createTestQueryClient();

    const { result } = await renderHook(() => useFoodHome(), { wrapper: wrapperFor(client) });
    await waitFor(() => expect(result.current.data).toBeDefined());
    const firstLoadData = result.current.data;

    // The next background refetch fails for both tables.
    fakeClient.queueTableResponse('item_categories', fakeSupabaseError('offline'));
    fakeClient.queueTableResponse('restaurants', fakeSupabaseError('offline'));
    await result.current.refetch();

    // Asserted straight off the `QueryClient`'s own cache state, not
    // `result.current.isError` -- TanStack Query's "tracked properties"
    // optimization (confirmed by reading this exact scenario against
    // `@tanstack/query-core` directly) only re-renders a consumer for a
    // field it actually read during render. `food/index.tsx` only ever
    // reads `home.isError` *inside* its own `if (!data)` branch (see this
    // file's top comment), so once `data` is populated it never reads
    // `isError` again either -- meaning the real screen has no reason to,
    // and never does, re-render off this failed background refetch at all.
    // The cache state below is the ground truth that the refetch really
    // did fail *and* left `data` untouched, independent of whether/how any
    // particular consumer's render happens to reflect it.
    const queryState = client.getQueryState(FOOD_HOME_QUERY_KEY);
    expect(queryState?.status).toBe('error');
    expect(queryState?.data).toEqual(firstLoadData);
    // The hook's own last-returned `data` is likewise untouched -- the one
    // property `food/index.tsx` actually branches on.
    expect(result.current.data).toEqual(firstLoadData);
  });
});

describe('prefetchFoodHome', () => {
  it('warms the shared queryClient cache under FOOD_HOME_QUERY_KEY', async () => {
    queueHomeSuccess();

    await prefetchFoodHome();

    expect(sharedQueryClient.getQueryData(FOOD_HOME_QUERY_KEY)).toEqual({
      categories: [{ id: 'rice', name: 'Rice', iconUrl: '' }],
      restaurants: [{ id: 'restaurant-1', name: 'Mogadishu Kitchen', description: 'Somali favourites', logoUrl: '' }],
    });
  });
});
