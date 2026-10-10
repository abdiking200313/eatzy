/**
 * Ports `flutter_app/lib/services/food/presentation/food_home_screen.dart`'s
 * search/category-filter behavior (issue #382) -- specifically
 * `_onSearchChanged`/`_selectCategory`/`_buildFilteredRestaurants`/
 * `_searchDebounce`, the server-side-filtered query that replaces the food
 * home screen's unfiltered restaurant list once a search term is typed
 * and/or a category chip is selected.
 *
 * The UI pass (a sibling issue) consumes this hook instead of re-building
 * its own debounce + `fetchRestaurants` call: it owns the search `<TextInput>`
 * and category-chip selection state and passes the current raw values in on
 * every render; this hook owns the debounce timer and the query.
 *
 * ## Deviation from the Dart source
 *
 * Dart's `_onSearchChanged` debounces every text change (typing or deleting
 * down to empty) by `_searchDebounce` (400ms), while its separate
 * `_clearSearch` (the search bar's explicit "X" button) bypasses the
 * debounce and clears the filter immediately. This hook only ever sees the
 * resulting string, not which of those two paths produced it, so it cannot
 * tell "typed backspace to empty" apart from "tapped clear". Rather than
 * leave the clear button feeling laggy, this hook treats *any* `searchQuery`
 * that trims to empty as an immediate (non-debounced) update -- the only
 * observable difference from Dart is that deleting a search term down to
 * nothing clears the filter instantly here, instead of after one more
 * `_searchDebounce` wait. A non-empty change is still debounced exactly as
 * in Dart. Category selection (`categoryId`) is applied immediately either
 * way, matching `_selectCategory`'s synchronous `setState`.
 */
import { useQuery } from '@tanstack/react-query';
import { useEffect, useState } from 'react';

import type { Restaurant } from './restaurant';
import { fetchRestaurants } from './restaurant-repository';

/** Mirrors `_searchDebounce` (`Duration(milliseconds: 400)`). */
export const FOOD_SEARCH_DEBOUNCE_MS = 400;

export interface UseFoodRestaurantSearchOptions {
  /** The search `<TextInput>`'s current raw value, updated on every keystroke. */
  searchQuery: string;
  /** The currently selected category chip's id, or `null` for "none selected". */
  categoryId: string | null;
  /** Overrides {@link FOOD_SEARCH_DEBOUNCE_MS} -- mainly for tests. */
  debounceMs?: number;
}

export interface UseFoodRestaurantSearchResult {
  /**
   * Whether a search term and/or category filter is active. `false` means
   * neither is active -- the caller should keep showing `useFoodHome`'s
   * unfiltered `restaurants` list instead of this hook's (empty)
   * `restaurants`/`isLoading`/`isError`. Mirrors Dart's
   * `_filteredRestaurants != null`.
   */
  isActive: boolean;
  /** Only meaningful when `isActive` is `true`. */
  restaurants: Restaurant[];
  isLoading: boolean;
  isError: boolean;
}

/**
 * Runs a debounced, server-side search/category-filtered restaurant query.
 * See this file's top comment for the full contract and its one documented
 * deviation from the Dart source.
 */
export function useFoodRestaurantSearch({
  searchQuery,
  categoryId,
  debounceMs = FOOD_SEARCH_DEBOUNCE_MS,
}: UseFoodRestaurantSearchOptions): UseFoodRestaurantSearchResult {
  const trimmedQuery = searchQuery.trim();
  const [prevTrimmedQuery, setPrevTrimmedQuery] = useState(trimmedQuery);
  const [debouncedQuery, setDebouncedQuery] = useState(trimmedQuery);

  // Adjusts state during rendering rather than in an effect -- React's
  // documented pattern for deriving state from a changed prop without an
  // extra render-then-effect round trip (see
  // https://react.dev/learn/you-might-not-need-an-effect#adjusting-some-state-when-a-prop-changes).
  // Only handles the immediate-clear case (see this file's top comment's
  // "Deviation from the Dart source" section); a non-empty change is
  // debounced by the effect below instead.
  if (trimmedQuery !== prevTrimmedQuery) {
    setPrevTrimmedQuery(trimmedQuery);
    if (trimmedQuery === '') {
      setDebouncedQuery('');
    }
  }

  useEffect(() => {
    if (trimmedQuery === '') return;
    const timer = setTimeout(() => setDebouncedQuery(trimmedQuery), debounceMs);
    return () => clearTimeout(timer);
  }, [trimmedQuery, debounceMs]);

  const hasCategory = !!categoryId && categoryId.length > 0;
  const hasSearch = debouncedQuery.length > 0;
  const isActive = hasCategory || hasSearch;

  const query = useQuery({
    queryKey: ['food-restaurant-search', debouncedQuery, categoryId ?? null] as const,
    queryFn: () =>
      fetchRestaurants({
        searchQuery: hasSearch ? debouncedQuery : undefined,
        categoryId: hasCategory ? (categoryId as string) : undefined,
      }),
    enabled: isActive,
  });

  return {
    isActive,
    restaurants: isActive ? query.data ?? [] : [],
    isLoading: isActive && query.isLoading,
    isError: isActive && query.isError,
  };
}
