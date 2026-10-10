/**
 * Ports `flutter_app/lib/platform/cache/catalog_queries.dart`'s
 * `CatalogQueries.foodHome()` / `FoodHomeData` typedef (issue #382): the
 * food home screen's unfiltered data -- category chips plus the default
 * restaurant list -- loaded together.
 *
 * Dart's `CatalogQueries` hand-rolls its own stale-while-revalidate cache
 * (`QueryCache`/`CachedQuery`, peeked synchronously then watched for
 * background refreshes). This app already replaced that whole pattern with
 * TanStack Query (issue #347) -- see `src/platform/query/query-persistence.
 * ts`'s top comment for why, and for the `catalogQueryKey` convention this
 * hook opts into below. `useQuery` alone reproduces both halves of Dart's
 * `peek()` + `watch()` pair: it renders whatever is already cached
 * (in-memory, or restored from on-device storage on a cold start) on the
 * very first render, then refetches in the background per the usual
 * `staleTime`/refetch-on-mount rules -- no separate "peek" call needed.
 */
import { useQuery } from '@tanstack/react-query';

import { queryClient } from '@/platform/query/query-client';
import { catalogQueryKey } from '@/platform/query/query-persistence';

import type { Category } from './category';
import { fetchCategories } from './category-repository';
import type { Restaurant } from './restaurant';
import { fetchRestaurants } from './restaurant-repository';

export type { Category, Restaurant };

/** The food home screen's unfiltered data -- mirrors Dart's `FoodHomeData` typedef. */
export interface FoodHomeData {
  categories: Category[];
  restaurants: Restaurant[];
}

/** This hook's shared cache key -- exported so `prefetchFoodHome` and tests can target the same entry. */
export const FOOD_HOME_QUERY_KEY = catalogQueryKey('food-home');

/**
 * Mirrors `CachedQuery`'s default `maxAge` (5 minutes) -- see
 * `query_cache.dart`'s `CachedQuery` constructor. `useFoodHome` overrides
 * the app-wide `queryClient` default (`staleTime: 60_000`, `query-client.
 * ts`) to match this specific Dart contract, the same way
 * `service-pricing-repository.ts`'s `useServicePricing` overrides it to
 * match its own 1-hour Dart `maxAge`.
 */
const FOOD_HOME_STALE_TIME_MS = 5 * 60 * 1000;

async function loadFoodHome(): Promise<FoodHomeData> {
  const [categories, restaurants] = await Promise.all([fetchCategories(), fetchRestaurants()]);
  return { categories, restaurants };
}

/**
 * Loads (and keeps fresh) the food home screen's categories + unfiltered
 * restaurant list. Shows the last-known cached data instantly (if any) while
 * refreshing in the background -- see this file's top comment.
 */
export function useFoodHome() {
  return useQuery({
    queryKey: FOOD_HOME_QUERY_KEY,
    queryFn: loadFoodHome,
    staleTime: FOOD_HOME_STALE_TIME_MS,
  });
}

/**
 * Warms `useFoodHome`'s cache ahead of navigating to the food home screen --
 * mirrors `CatalogQueries.prefetchHome()`'s `foodHome().prefetch()` call.
 * Not wired into any startup/navigation call site by this issue: that is
 * `CatalogQueries.prefetchHome()`'s other half (`homeStores()`) already
 * covered by issue #373, and this repo has no equivalent "about to open
 * food" call site yet for this one to hook into. Exported for whichever
 * future issue adds it.
 */
export function prefetchFoodHome(): Promise<void> {
  return queryClient.prefetchQuery({
    queryKey: FOOD_HOME_QUERY_KEY,
    queryFn: loadFoodHome,
    staleTime: FOOD_HOME_STALE_TIME_MS,
  });
}
