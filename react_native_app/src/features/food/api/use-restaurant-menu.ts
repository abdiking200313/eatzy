/**
 * Ports `CatalogQueries.restaurantMenu` (`flutter_app/lib/platform/cache/
 * catalog_queries.dart`) and `RestaurantScreen._loadLocations` (issue #383)
 * onto TanStack Query -- see `use-food-home.ts`'s top comment for how
 * `useQuery` replaces Dart's `CachedQuery` `peek()` + `watch()` pair.
 */
import { useQuery } from '@tanstack/react-query';

import { catalogQueryKey } from '@/platform/query/query-persistence';

import type { RestaurantLocation } from './restaurant-location';
import { fetchRestaurantLocations } from './restaurant-location';
import type { RestaurantMenu } from './restaurant-menu';
import { fetchRestaurantMenu } from './restaurant-menu-repository';

/** The persisted cache key for one restaurant's menu -- mirrors Dart's `'restaurant_menu:$restaurantId'`. */
export function restaurantMenuQueryKey(restaurantId: string) {
  return catalogQueryKey('restaurant-menu', restaurantId);
}

/**
 * Loads (and keeps fresh) one restaurant's menu. `staleTime: 0` mirrors the
 * Dart query's `maxAge: Duration.zero`: the last-known menu shows instantly,
 * but prices are refreshed in the background on every open rather than
 * trusted for the usual five minutes.
 */
export function useRestaurantMenu(restaurantId: string) {
  return useQuery<RestaurantMenu>({
    queryKey: restaurantMenuQueryKey(restaurantId),
    queryFn: () => fetchRestaurantMenu(restaurantId),
    staleTime: 0,
  });
}

/**
 * A restaurant's physical locations, for the header's "store a • store b"
 * line. Any failure resolves to an empty list -- mirrors `_loadLocations`'s
 * `on Object { return const []; }`, since the line is purely informational.
 * Not a catalog (persisted) key: the Dart source never cached this either.
 */
export function useRestaurantLocations(restaurantId: string) {
  return useQuery<RestaurantLocation[]>({
    queryKey: ['restaurant-locations', restaurantId],
    queryFn: async () => {
      try {
        return await fetchRestaurantLocations(restaurantId);
      } catch {
        return [];
      }
    },
  });
}
