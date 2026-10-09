/**
 * Persists the shared TanStack Query cache (`query-client.ts`, issue #347)
 * to on-device storage, so a relaunch can render the last-known "catalog"
 * data immediately instead of a blank/loading screen (issue #372).
 *
 * This is infrastructure, not a line-for-line port. Flutter's
 * `lib/platform/cache/query_cache.dart` + `catalog_queries.dart` are a
 * hand-rolled stale-while-revalidate cache (its own LRU eviction, its own
 * concurrent-request dedup, its own disk mirroring) because Dart has no
 * TanStack Query equivalent. This RN app already replaced that whole
 * pattern with `@tanstack/react-query` (issue #347) -- so this module only
 * adds *disk persistence* on top of the query client that already exists,
 * using TanStack's own persistence primitives
 * (`@tanstack/query-async-storage-persister` +
 * `@tanstack/react-query-persist-client`) rather than reimplementing SWR,
 * eviction, or dedup, since TanStack Query already does all of that for
 * every query, persisted or not.
 *
 * ## The `catalog` convention
 *
 * Dart's `CatalogQueries` hardcodes an allowlist of cache keys
 * (`home_stores`, `food_home`, `restaurant_menu:<id>`) that are safe to
 * persist -- public, non-user-specific catalog data (as opposed to a cart,
 * an order, or a profile, which must never be written to a shared disk
 * cache). No RN catalog query hooks exist yet (food/grocery/pharmacy
 * catalog screens land in a later phase), so there is no concrete key list
 * to hardcode *from* yet. Instead, this module generalizes Dart's allowlist
 * into a convention future hooks opt into themselves:
 *
 * - Build every catalog query's `queryKey` with {@link catalogQueryKey},
 *   which always starts with the `'catalog'` tag, e.g.
 *   `catalogQueryKey('food-home')` or
 *   `catalogQueryKey('restaurant-menu', restaurantId)`.
 * - {@link shouldPersistCatalogQuery} (wired into `queryPersistOptions`
 *   below) only persists a query whose key starts with that tag, so a
 *   query that doesn't opt in (anything user-specific: carts, orders,
 *   profile, auth) is never written to disk -- the same safety property as
 *   Dart's allowlist, minus needing to maintain the list by hand here.
 *
 * A future issue adding, say, a food-home query hook should write
 * `useQuery({ queryKey: catalogQueryKey('food-home'), ... })` to get disk
 * persistence "for free" from this module, with no further wiring needed
 * in this file.
 *
 * ## Per-query freshness is *not* this module's job
 *
 * Dart's per-query `maxAge` (`CachedQuery`'s default 5 minutes, or
 * `Duration.zero` for a restaurant menu -- i.e. "always revalidate in the
 * background") maps directly onto TanStack Query's own `staleTime` option,
 * set by each query hook on its own `useQuery` call. There is nothing to
 * apply that to yet (no catalog hooks exist), and this shared persistence
 * module has no business overriding a future hook's own `staleTime`
 * globally -- so it is deliberately *not* reproduced here. When the
 * food-home hook above lands, it sets its own `staleTime` (`0` for "always
 * revalidate", mirroring Dart's restaurant-menu `Duration.zero`; a longer
 * value for data that changes less often) the same way any other
 * `useQuery` call would, independent of this module.
 *
 * `maxAge` below is the *other* Dart constant this module is responsible
 * for, `QueryCache.maxDiskAge` (7 days): how old an entire persisted
 * snapshot can be before TanStack Query discards it wholesale on restore,
 * independent of any single query's own staleness.
 */
import AsyncStorage from '@react-native-async-storage/async-storage';
import { createAsyncStoragePersister } from '@tanstack/query-async-storage-persister';
import { defaultShouldDehydrateQuery, type OmitKeyof, type Query, type QueryKey } from '@tanstack/react-query';
import type { PersistQueryClientOptions } from '@tanstack/react-query-persist-client';

import { sessionResetRegistry } from '@/stores/session-reset-registry';

/** Every catalog query's `queryKey` must start with this tag -- see this file's top comment. */
export const CATALOG_QUERY_TAG = 'catalog' as const;

/**
 * Builds a `queryKey` for a catalog (public, non-user-specific) query.
 * Opts the query into on-device persistence via
 * {@link shouldPersistCatalogQuery} -- this is the convention future
 * food/grocery/pharmacy catalog query hooks should follow (see this file's
 * top comment).
 */
export function catalogQueryKey(...parts: readonly unknown[]): QueryKey {
  return [CATALOG_QUERY_TAG, ...parts];
}

/** Whether `queryKey` was built with {@link catalogQueryKey}. */
export function isCatalogQueryKey(queryKey: QueryKey): boolean {
  return queryKey[0] === CATALOG_QUERY_TAG;
}

/**
 * The persistence layer's `shouldDehydrateQuery` predicate: only a query
 * that is both "normally safe to dehydrate" (TanStack's own
 * `defaultShouldDehydrateQuery` -- excludes pending/errored queries) *and*
 * tagged with {@link catalogQueryKey} is written to disk. Everything else
 * (carts, orders, profile, auth, or any future query that simply doesn't
 * opt in) stays in-memory only.
 */
export function shouldPersistCatalogQuery(query: Query): boolean {
  return defaultShouldDehydrateQuery(query) && isCatalogQueryKey(query.queryKey);
}

/** Mirrors Dart's `QueryCache.maxDiskAge` (7 days) -- see this file's top comment. */
export const QUERY_PERSISTENCE_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;

/** Storage key the persisted snapshot is written under in AsyncStorage. */
const PERSISTENCE_STORAGE_KEY = 'eatzy-query-cache';

/**
 * The persister itself, backed by `@react-native-async-storage/async-storage`
 * (already a dependency, already mocked for Jest -- see `jest.config.js`).
 * Exported so the reset-registry callback below (and tests) can call
 * `removeClient()` directly: confirmed by reading
 * `@tanstack/query-persist-client-core`'s `Persister` interface, which
 * `createAsyncStoragePersister`'s return type is declared as --
 * `{ persistClient, restoreClient, removeClient }`, all three required.
 * `removeClient()` deletes the one persisted snapshot from `AsyncStorage`.
 */
export const queryPersister = createAsyncStoragePersister({
  storage: AsyncStorage,
  key: PERSISTENCE_STORAGE_KEY,
});

/**
 * Passed as `persistOptions` to `PersistQueryClientProvider`
 * (`src/app/_layout.tsx`) -- bundles the persister, the 7-day `maxAge`, and
 * the catalog-only `shouldDehydrateQuery` predicate in one place so the
 * root layout doesn't need to know this module's internals, just that it
 * exists and must be passed through.
 */
export const queryPersistOptions: OmitKeyof<PersistQueryClientOptions, 'queryClient'> = {
  persister: queryPersister,
  maxAge: QUERY_PERSISTENCE_MAX_AGE_MS,
  dehydrateOptions: {
    shouldDehydrateQuery: shouldPersistCatalogQuery,
  },
};

/**
 * Clears the on-disk persisted snapshot on every account change
 * (sign-out, sign-in, or switching between two accounts on one device),
 * registered through the shared `sessionResetRegistry` (issue #359)
 * exactly as any other feature module would register its own reset
 * behavior.
 *
 * This is *in addition to*, not a replacement for,
 * `AccountStateCoordinator`'s existing in-memory `queryClient.clear()`
 * (see `src/stores/account-state-coordinator.ts`'s top comment): clearing
 * only the in-memory cache would leave the on-disk snapshot in place, and
 * the *next* signed-in account on this device could then have the
 * previous account's catalog data restored into their own session on
 * their next cold start. Registering here, rather than teaching
 * `account-state-coordinator.ts` about this module, keeps that shared
 * platform file from needing to know this feature-specific persistence
 * layer exists at all -- the same reasoning that file's own comment gives
 * for why a cart store registers itself instead.
 *
 * Registered as a module-level side effect: importing this module (as
 * `_layout.tsx` does, to get `queryPersistOptions`) is what activates it,
 * the same pattern `src/platform/supabase/client.ts` uses for its own
 * app-wide singleton setup.
 */
sessionResetRegistry.register(() => {
  void queryPersister.removeClient();
});
