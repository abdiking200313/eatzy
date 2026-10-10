/**
 * Ports the debounce-timing half of
 * `flutter_app/test/food_home_screen_test.dart`'s "typing a search term
 * debounces before filtering" case (the screen-level half -- the actual
 * `<TextInput>`/clear-button interaction -- is ported at
 * `../../../app/(app)/(tabs)/food/index.test.tsx`), plus this hook's own
 * documented "Deviation from the Dart source" contract (its top comment):
 * an empty search clears immediately, a non-empty one debounces by
 * `FOOD_SEARCH_DEBOUNCE_MS`, and category selection is always immediate.
 *
 * Uses `jest.useFakeTimers()` the same way `use-cart-snackbar.test.ts`
 * tests its own `setTimeout`-driven hook. `@/platform/supabase/client` is
 * mocked with a `FakeSupabaseClient` the same way `use-food-home.test.tsx`
 * does, since `restaurant-repository.ts` falls back to the real `supabase`
 * import when this hook calls `fetchRestaurants()` with no injected client.
 */
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { act, renderHook, waitFor } from '@testing-library/react-native';
import type { ReactNode } from 'react';

import { supabase } from '@/platform/supabase/client';
import { createFakeSupabaseClient, fakeSupabaseError, fakeSupabaseOk } from '@/test-utils/fake-supabase-client';

import { FOOD_SEARCH_DEBOUNCE_MS, useFoodRestaurantSearch, type UseFoodRestaurantSearchOptions } from './use-food-restaurant-search';

jest.mock('@/platform/supabase/client', () => ({
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  supabase: require('@/test-utils/fake-supabase-client').createFakeSupabaseClient(),
}));

const fakeClient = supabase as unknown as ReturnType<typeof createFakeSupabaseClient>;

const riceBowlRow = { id: 'restaurant-2', name: 'Rice Bowl', description: 'Rice specialists', logo_url: '' };
const kitchenExpressRow = { id: 'restaurant-3', name: 'Kitchen Express', description: 'Fast Somali food', logo_url: '' };

function queryClientWrapper() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  function Wrapper({ children }: { children: ReactNode }) {
    return <QueryClientProvider client={client}>{children}</QueryClientProvider>;
  }
  return Wrapper;
}

function renderSearch(initialProps: UseFoodRestaurantSearchOptions) {
  return renderHook((props: UseFoodRestaurantSearchOptions) => useFoodRestaurantSearch(props), {
    initialProps,
    wrapper: queryClientWrapper(),
  });
}

beforeEach(() => {
  jest.useFakeTimers();
  // `fakeClient` is a module-level singleton (see the `jest.mock` factory
  // above), shared by every test in this file -- clear its recorded calls
  // so an assertion like `expect(fakeClient.calls).toEqual([])` reflects
  // only the test currently running.
  fakeClient.calls.length = 0;
});

afterEach(() => {
  jest.useRealTimers();
});

describe('useFoodRestaurantSearch', () => {
  it('is inactive, and queries nothing, with no search term and no category', async () => {
    const { result } = await renderSearch({ searchQuery: '', categoryId: null });

    expect(result.current.isActive).toBe(false);
    expect(result.current.restaurants).toEqual([]);
    expect(fakeClient.calls).toEqual([]);
  });

  it('selecting a category filters immediately, without waiting for the debounce', async () => {
    fakeClient.queueTableResponse('restaurants', fakeSupabaseOk([riceBowlRow]));
    const { result, rerender } = await renderSearch({ searchQuery: '', categoryId: null });

    await act(async () => {
      rerender({ searchQuery: '', categoryId: 'rice' });
    });

    await waitFor(() => expect(result.current.isActive).toBe(true));
    await waitFor(() => expect(result.current.restaurants).toHaveLength(1));
    expect(result.current.restaurants[0].name).toBe('Rice Bowl');

    const call = fakeClient.calls[0];
    const steps = call.kind === 'table' ? call.steps : [];
    expect(steps.find((step) => step.method === 'eq')?.args).toEqual(['menu_items.categorie_id', 'rice']);
    expect(steps.some((step) => step.method === 'ilike')).toBe(false);
  });

  it('tapping the same category again (categoryId -> null) clears the filter', async () => {
    fakeClient.queueTableResponse('restaurants', fakeSupabaseOk([riceBowlRow]));
    const { result, rerender } = await renderSearch({ searchQuery: '', categoryId: 'rice' });
    await waitFor(() => expect(result.current.restaurants).toHaveLength(1));

    await act(async () => {
      rerender({ searchQuery: '', categoryId: null });
    });

    expect(result.current.isActive).toBe(false);
    expect(result.current.restaurants).toEqual([]);
  });

  it('typing a search term does not query until FOOD_SEARCH_DEBOUNCE_MS has passed', async () => {
    fakeClient.queueTableResponse('restaurants', fakeSupabaseOk([kitchenExpressRow]));
    const { result, rerender } = await renderSearch({ searchQuery: '', categoryId: null });

    await act(async () => {
      rerender({ searchQuery: 'kitchen', categoryId: null });
    });

    // Still within the debounce window -- no query fired, and the screen
    // keeps showing the unfiltered list (isActive stays false) in the
    // meantime.
    await act(async () => {
      jest.advanceTimersByTime(100);
    });
    expect(result.current.isActive).toBe(false);
    expect(fakeClient.calls).toEqual([]);

    await act(async () => {
      jest.advanceTimersByTime(FOOD_SEARCH_DEBOUNCE_MS - 100);
    });

    await waitFor(() => expect(result.current.isActive).toBe(true));
    await waitFor(() => expect(result.current.restaurants).toHaveLength(1));
    expect(result.current.restaurants[0].name).toBe('Kitchen Express');
    const call = fakeClient.calls[0];
    const steps = call.kind === 'table' ? call.steps : [];
    expect(steps.some((step) => step.method === 'ilike' && step.args[1] === '%kitchen%')).toBe(true);
  });

  it('a mid-debounce keystroke resets the timer rather than firing early', async () => {
    fakeClient.queueTableResponse('restaurants', fakeSupabaseOk([kitchenExpressRow]));
    const { result, rerender } = await renderSearch({ searchQuery: '', categoryId: null });

    await act(async () => {
      rerender({ searchQuery: 'kitc', categoryId: null });
    });
    await act(async () => {
      jest.advanceTimersByTime(300);
    });
    await act(async () => {
      rerender({ searchQuery: 'kitchen', categoryId: null });
    });
    // Only 300ms since this second change -- the full debounce hasn't
    // elapsed again yet, even though 600ms has passed since the first
    // keystroke.
    await act(async () => {
      jest.advanceTimersByTime(300);
    });
    expect(result.current.isActive).toBe(false);
    expect(fakeClient.calls).toEqual([]);

    await act(async () => {
      jest.advanceTimersByTime(100);
    });
    await waitFor(() => expect(result.current.isActive).toBe(true));
  });

  it('clearing the search (deleting back to empty) clears the filter immediately -- the documented deviation from the debounced Dart source', async () => {
    fakeClient.queueTableResponse('restaurants', fakeSupabaseOk([kitchenExpressRow]));
    const { result, rerender } = await renderSearch({ searchQuery: '', categoryId: null });

    await act(async () => {
      rerender({ searchQuery: 'kitchen', categoryId: null });
    });
    await act(async () => {
      jest.advanceTimersByTime(FOOD_SEARCH_DEBOUNCE_MS);
    });
    await waitFor(() => expect(result.current.isActive).toBe(true));

    await act(async () => {
      rerender({ searchQuery: '', categoryId: null });
    });

    // No further timer advance needed -- clearing to empty is synchronous.
    expect(result.current.isActive).toBe(false);
    expect(result.current.restaurants).toEqual([]);
  });

  it('a blank/whitespace-only search behaves the same as empty -- trimmed before deciding active/inactive', async () => {
    const { result, rerender } = await renderSearch({ searchQuery: '', categoryId: null });

    await act(async () => {
      rerender({ searchQuery: '   ', categoryId: null });
    });

    expect(result.current.isActive).toBe(false);
    expect(fakeClient.calls).toEqual([]);
  });

  it('surfaces isLoading/isError only while active', async () => {
    fakeClient.queueTableResponse('restaurants', fakeSupabaseError('offline'));
    const { result, rerender } = await renderSearch({ searchQuery: '', categoryId: null });

    await act(async () => {
      rerender({ searchQuery: '', categoryId: 'rice' });
    });

    await waitFor(() => expect(result.current.isError).toBe(true));
    expect(result.current.restaurants).toEqual([]);
  });
});
