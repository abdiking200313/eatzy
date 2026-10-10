/**
 * Data hooks for the food "browse" screens (issue #385):
 * `src/app/(app)/(tabs)/food/categories.tsx` (ports
 * `food_categories_screen.dart`) and `src/app/(app)/(tabs)/food/explore.tsx`
 * (ports `food_explore_screen.dart`).
 *
 * Both Dart screens hold a one-shot `late final Future` built from
 * `CategoryRepository().fetchCategories()` /
 * `RestaurantRepository().fetchRestaurants(categoryId: ...)`. Here that is a
 * TanStack Query `useQuery` over the same repository functions, keyed with
 * `catalogQueryKey` like `use-food-home.ts`/`use-restaurant-menu.ts` (public
 * catalog data, opted into on-device persistence).
 */
import { useQuery } from '@tanstack/react-query';

import { catalogQueryKey } from '@/platform/query/query-persistence';

import { fetchCategories } from './category-repository';
import { fetchRestaurants } from './restaurant-repository';

/** `useFoodCategories`'s cache key. */
export const FOOD_CATEGORIES_QUERY_KEY = catalogQueryKey('food-categories');

/** `useFoodExploreRestaurants`'s cache key, parameterized by the optional category filter. */
export function foodExploreQueryKey(categoryId: string | null) {
  return catalogQueryKey('food-explore', categoryId);
}

/** The full food category list -- mirrors `FoodCategoriesScreen`'s `_categories` future. */
export function useFoodCategories() {
  return useQuery({
    queryKey: FOOD_CATEGORIES_QUERY_KEY,
    queryFn: () => fetchCategories(),
  });
}

/**
 * The explore screen's restaurant list, optionally narrowed server-side to
 * one `item_categories.id` -- mirrors `FoodExploreScreen`'s `_restaurants`
 * future (`fetchRestaurants(categoryId: widget.categoryId)`). A blank
 * `categoryId` is treated as "no filter", same as the repository itself.
 */
export function useFoodExploreRestaurants(categoryId: string | null) {
  const normalized = categoryId && categoryId.length > 0 ? categoryId : null;
  return useQuery({
    queryKey: foodExploreQueryKey(normalized),
    queryFn: () => fetchRestaurants(normalized ? { categoryId: normalized } : {}),
  });
}
