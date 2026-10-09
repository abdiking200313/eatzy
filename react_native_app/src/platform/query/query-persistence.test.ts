/**
 * Focused tests for the persistence infrastructure this issue (#372) adds
 * on top of TanStack Query (`query-persistence.ts`'s top comment explains
 * why there is no literal port of `flutter_app/test/query_cache_test.dart`
 * here): that Dart test exercises a hand-rolled cache's own internals --
 * stale-while-revalidate timing, LRU eviction, concurrent-request dedup --
 * which TanStack Query already implements and already tests for every
 * query, persisted or not. There is nothing of that kind for this module
 * to reimplement or re-test. What *is* this module's own responsibility,
 * and so what's covered below, is: the catalog key-prefix convention, the
 * `shouldDehydrateQuery` predicate built from it, the 7-day `maxAge`
 * configuration, and the reset-registry wiring.
 */
import { QueryClient } from '@tanstack/react-query';

import { sessionResetRegistry } from '@/stores/session-reset-registry';

import {
  CATALOG_QUERY_TAG,
  catalogQueryKey,
  isCatalogQueryKey,
  queryPersistOptions,
  queryPersister,
  QUERY_PERSISTENCE_MAX_AGE_MS,
  shouldPersistCatalogQuery,
} from './query-persistence';

describe('catalogQueryKey / isCatalogQueryKey', () => {
  it('builds a key tagged with the catalog prefix', () => {
    expect(catalogQueryKey('food-home')).toEqual([CATALOG_QUERY_TAG, 'food-home']);
    expect(catalogQueryKey('restaurant-menu', 'restaurant-1')).toEqual([
      CATALOG_QUERY_TAG,
      'restaurant-menu',
      'restaurant-1',
    ]);
  });

  it('recognizes a key built by catalogQueryKey, and rejects one that is not', () => {
    expect(isCatalogQueryKey(catalogQueryKey('food-home'))).toBe(true);
    expect(isCatalogQueryKey(['cart', 'items'])).toBe(false);
    expect(isCatalogQueryKey([])).toBe(false);
  });
});

describe('shouldPersistCatalogQuery', () => {
  let client: QueryClient;

  beforeEach(() => {
    client = new QueryClient();
  });

  // Each successfully-resolved query above schedules its own garbage-
  // collection timer (`gcTime`, 5 minutes by default) the moment it's
  // created -- clearing the cache (which destroys every query, canceling
  // its pending timer) keeps that real `setTimeout` from outliving this
  // test and showing up as a Jest "worker process failed to exit
  // gracefully" warning.
  afterEach(() => {
    client.clear();
  });

  it('includes a successfully-resolved catalog-tagged query', () => {
    const key = catalogQueryKey('food-home');
    client.setQueryData(key, { stores: [] });
    const query = client.getQueryCache().find({ queryKey: key });

    expect(query).toBeDefined();
    expect(shouldPersistCatalogQuery(query!)).toBe(true);
  });

  it('excludes a successfully-resolved query that is not catalog-tagged', () => {
    const key = ['cart', 'items'];
    client.setQueryData(key, [{ id: 1 }]);
    const query = client.getQueryCache().find({ queryKey: key });

    expect(query).toBeDefined();
    expect(shouldPersistCatalogQuery(query!)).toBe(false);
  });

  it('excludes a catalog-tagged query that has not resolved successfully (pending), deferring to defaultShouldDehydrateQuery', () => {
    const key = catalogQueryKey('still-loading');
    // Builds the query in the cache without resolving it, i.e. still
    // 'pending' -- mirrors TanStack's own defaultShouldDehydrateQuery
    // excluding anything but a 'success' query, combined with (not
    // replacing) this module's own catalog-prefix check.
    const query = client.getQueryCache().build(client, { queryKey: key });

    expect(query.state.status).toBe('pending');
    expect(shouldPersistCatalogQuery(query)).toBe(false);
  });
});

describe('QUERY_PERSISTENCE_MAX_AGE_MS', () => {
  it('matches Dart QueryCache.maxDiskAge (7 days)', () => {
    expect(QUERY_PERSISTENCE_MAX_AGE_MS).toBe(7 * 24 * 60 * 60 * 1000);
  });
});

describe('queryPersistOptions', () => {
  it('wires the persister, 7-day maxAge, and catalog-only predicate together', () => {
    expect(queryPersistOptions.persister).toBe(queryPersister);
    expect(queryPersistOptions.maxAge).toBe(QUERY_PERSISTENCE_MAX_AGE_MS);
    expect(queryPersistOptions.dehydrateOptions?.shouldDehydrateQuery).toBe(
      shouldPersistCatalogQuery,
    );
  });
});

describe('account-change reset wiring', () => {
  it('registers a sessionResetRegistry callback that clears the persisted snapshot via queryPersister.removeClient', () => {
    const removeClientSpy = jest
      .spyOn(queryPersister, 'removeClient')
      .mockResolvedValue(undefined);

    sessionResetRegistry.notifyAll('user-1');

    expect(removeClientSpy).toHaveBeenCalledTimes(1);
    removeClientSpy.mockRestore();
  });
});
