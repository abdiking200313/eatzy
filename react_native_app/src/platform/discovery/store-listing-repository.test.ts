/**
 * Ports `flutter_app/test/store_listing_repository_test.dart` (issue #373 /
 * P4-02). The Dart test injects fake *per-vertical repository* objects;
 * this port injects the narrower `VerticalFetch` functions this class
 * actually depends on (see `store-listing-repository.ts`'s top comment for
 * why), each returning the already-mapped `StoreListing[]` shape.
 */
import { ErrorReporting, type ErrorReporter } from '@/platform/error-reporting/error-reporter';

import { StoreListingRepository, StoreListingUnavailableException } from './store-listing-repository';
import type { StoreListing } from './store-listing';

// This test always injects fake fetchers, never the default Supabase-backed
// ones, but the module still imports the real `supabase` client at load
// time for its default parameter -- mock it out so that import doesn't
// throw on a missing `EXPO_PUBLIC_SUPABASE_URL` env var (same approach as
// merchant-role-service.test.ts).
jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

class FakeErrorReporter implements ErrorReporter {
  readonly reported: { error: unknown; context?: string }[] = [];

  reportError(error: unknown, _stack?: string, context?: string): void {
    this.reported.push({ error, context });
  }
}

const food: StoreListing = { id: 'r1', serviceId: 'food', name: 'Pizza Place', subtitle: '', imageUrl: null, route: '/food/restaurants/r1' };
const pharmacy: StoreListing = { id: 'p1', serviceId: 'pharmacy', name: 'Downtown Pharmacy', subtitle: '', imageUrl: null, route: '/pharmacy/stores/p1' };

function throwing(error: unknown) {
  return async (): Promise<StoreListing[]> => {
    throw error;
  };
}

function resolving(stores: StoreListing[]) {
  return async (): Promise<StoreListing[]> => stores;
}

describe('StoreListingRepository (ports issue #286)', () => {
  let originalReporter: ErrorReporter;
  let fakeReporter: FakeErrorReporter;

  beforeEach(() => {
    originalReporter = ErrorReporting.instance;
    fakeReporter = new FakeErrorReporter();
    ErrorReporting.instance = fakeReporter;
  });

  afterEach(() => {
    ErrorReporting.instance = originalReporter;
  });

  it('throws instead of silently returning an empty list when every vertical fails, and reports every failure', async () => {
    const repository = new StoreListingRepository({
      fetchFoodStores: throwing(new Error('food down')),
      fetchGroceryStores: throwing(new Error('grocery down')),
      fetchPharmacyStores: throwing(new Error('pharmacy down')),
    });

    await expect(repository.fetchStores()).rejects.toBeInstanceOf(StoreListingUnavailableException);

    expect(fakeReporter.reported).toHaveLength(3);
    expect(fakeReporter.reported.map((r) => r.context)).toEqual(
      expect.arrayContaining(['StoreListingRepository._fetchFood', 'StoreListingRepository._fetchGrocery', 'StoreListingRepository._fetchPharmacy']),
    );
  });

  it('never exposes raw error detail in its message -- safe to show directly in the UI', () => {
    const exception = new StoreListingUnavailableException();

    expect(exception.message).not.toContain('Error');
    expect(exception.message.length).toBeGreaterThan(0);
  });

  it('returns the stores that did load and still reports just the failures when only some verticals fail', async () => {
    const repository = new StoreListingRepository({
      fetchFoodStores: resolving([food]),
      fetchGroceryStores: throwing(new Error('grocery down')),
      fetchPharmacyStores: resolving([pharmacy]),
    });

    const stores = await repository.fetchStores();

    expect(stores.map((s) => s.id)).toEqual(expect.arrayContaining(['r1', 'p1']));
    expect(fakeReporter.reported).toHaveLength(1);
    expect(fakeReporter.reported[0].context).toBe('StoreListingRepository._fetchGrocery');
  });

  it('throws and reports when a single-vertical filter fails', async () => {
    const repository = new StoreListingRepository({
      fetchFoodStores: throwing(new Error('food down')),
      fetchGroceryStores: resolving([]),
      fetchPharmacyStores: resolving([]),
    });

    await expect(repository.fetchStores({ filter: 'food' })).rejects.toBeInstanceOf(StoreListingUnavailableException);
    expect(fakeReporter.reported).toHaveLength(1);
    expect(fakeReporter.reported[0].context).toBe('StoreListingRepository._fetchFood');
  });

  it('returns an empty list without throwing, and reports nothing, when every vertical is genuinely empty', async () => {
    const repository = new StoreListingRepository({
      fetchFoodStores: resolving([]),
      fetchGroceryStores: resolving([]),
      fetchPharmacyStores: resolving([]),
    });

    const stores = await repository.fetchStores();

    expect(stores).toEqual([]);
    expect(fakeReporter.reported).toEqual([]);
  });
});
