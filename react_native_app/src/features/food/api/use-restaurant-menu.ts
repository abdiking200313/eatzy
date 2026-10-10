/**
 * Ports `flutter_app/lib/platform/cache/catalog_queries.dart`'s
 * `CatalogQueries.restaurantMenu(restaurantId)` (issue #383): a restaurant's
 * menu, shown instantly from cache but refreshed in the background on
 * every open rather than trusted for the usual five minutes, since it
 * carries prices -- the order RPC still recomputes prices server-side
 * either way. See `use-food-home.ts`'s top comment for why this reuses
 * TanStack Query instead of porting Dart's hand-rolled `QueryCache`, and
 * `query-persistence.ts`'s top comment for the `catalogQueryKey`
 * convention this hook opts into.
 */
import { useQuery } from '@tanstack/react-query';

import { queryClient } from '@/platform/query/query-client';
import { catalogQueryKey } from '@/platform/query/query-persistence';

import { fetchMenu } from './restaurant-menu-repository';
import type { RestaurantMenu } from './restaurant-menu';

export type { RestaurantMenu };

/** This hook's cache key, parameterized by `restaurantId` -- exported so `prefetchRestaurantMenu` and tests can target the same entry. */
export function restaurantMenuQueryKey(restaurantId: string) {
  return catalogQueryKey('restaurant-menu', restaurantId);
}

/**
 * Mirrors `CachedQuery`'s `Duration.zero` `maxAge` for this one query (see
 * `catalog_queries.dart`'s `restaurantMenu` doc comment): always stale, so
 * every mount/refetch revalidates in the background even though cached data
 * still renders instantly. Overrides the app-wide `queryClient` default
 * (`staleTime: 60_000`, `query-client.ts`) the same way
 * `use-food-home.ts`'s `useFoodHome` overrides it to match its own 5-minute
 * Dart `maxAge`.
 */
export const RESTAURANT_MENU_STALE_TIME_MS = 0;

/**
 * Loads (and keeps fresh) one restaurant's menu. Shows the last-known
 * cached menu instantly (if any) while refreshing in the background -- see
 * this file's top comment.
 */
export function useRestaurantMenu(restaurantId: string) {
  return useQuery({
    queryKey: restaurantMenuQueryKey(restaurantId),
    queryFn: () => fetchMenu(restaurantId),
    staleTime: RESTAURANT_MENU_STALE_TIME_MS,
    enabled: restaurantId.length > 0,
  });
}

/**
 * Warms `useRestaurantMenu`'s cache ahead of navigating to a restaurant
 * screen -- mirrors `CatalogQueries.prefetchMenus`' per-restaurant
 * `restaurantMenu(id).prefetch()` call. Callers wanting
 * `prefetchMenus`' "skip if already cached" behavior should check
 * `queryClient.getQueryData(restaurantMenuQueryKey(restaurantId))` first;
 * this function itself always fetches.
 */
export function prefetchRestaurantMenu(restaurantId: string): Promise<void> {
  return queryClient.prefetchQuery({
    queryKey: restaurantMenuQueryKey(restaurantId),
    queryFn: () => fetchMenu(restaurantId),
    staleTime: RESTAURANT_MENU_STALE_TIME_MS,
  });
}
