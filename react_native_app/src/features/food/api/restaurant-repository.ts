/**
 * Ports `flutter_app/lib/services/food/data/restaurant_repository.dart`'s
 * `RestaurantRepository.fetchRestaurants` (issue #382) -- see
 * `category-repository.ts`'s top comment for why this is a free function
 * with an injectable client rather than Dart's constructor-injected class.
 */
import { supabase } from '@/platform/supabase/client';

import { restaurantFromRow, type Restaurant, type RestaurantRow } from './restaurant';

/**
 * Default page size for restaurant queries below.
 *
 * The home screen does not yet page through the plain unfiltered listing,
 * so `limit`/`offset` here only bound the worst case (every restaurant in
 * the catalog fetched on every load). A real "load more"/infinite scroll
 * contract for the home feed is left as a follow-up -- mirrors the Dart
 * repository's own `defaultPageSize` comment.
 */
export const RESTAURANT_DEFAULT_PAGE_SIZE = 50;

/**
 * The slice of `supabase` {@link fetchRestaurants} depends on -- see
 * `category-repository.ts`'s `CategorySource` doc comment. `select`'s
 * return type is widened to `any` of this same chain shape rather than two
 * separate declared shapes (with/without the `menu_items!inner(...)` join
 * column), since both branches below call the same `eq`/`ilike`/`order`/
 * `range` methods on whatever `select` returns either way.
 */
export interface RestaurantSource {
  from(table: 'restaurants'): RestaurantFilterChain;
}

export interface RestaurantFilterChain {
  select(columns: string): RestaurantFilterChain;
  eq(column: string, value: unknown): RestaurantFilterChain;
  ilike(column: string, pattern: string): RestaurantFilterChain;
  order(column: string): RestaurantFilterChain;
  range(from: number, to: number): PromiseLike<{ data: RestaurantRow[] | null; error: { message: string } | null }>;
}

export interface FetchRestaurantsOptions {
  /** A case-insensitive substring match against `restaurants.name`. Blank/omitted means "no search filter". */
  searchQuery?: string | null;
  /**
   * Narrows to restaurants with at least one menu item in this
   * `item_categories.id`, joined via `menu_items.categorie_id`.
   * Blank/omitted means "no category filter".
   */
  categoryId?: string | null;
  limit?: number;
  offset?: number;
}

/**
 * Fetches restaurants, optionally narrowed by `searchQuery` and/or
 * `categoryId`, bounded to `limit` rows starting at `offset`. Mirrors the
 * Dart repository's `fetchRestaurants` exactly, including its two query
 * shapes: the `menu_items!inner(categorie_id)` join is only added to
 * `select` when a category filter is active, since an unconditional inner
 * join would otherwise drop every restaurant with no menu items at all.
 */
export async function fetchRestaurants(
  { searchQuery, categoryId, limit = RESTAURANT_DEFAULT_PAGE_SIZE, offset = 0 }: FetchRestaurantsOptions = {},
  client: RestaurantSource = supabase as unknown as RestaurantSource,
): Promise<Restaurant[]> {
  const trimmedQuery = searchQuery?.trim();
  const hasSearch = !!trimmedQuery && trimmedQuery.length > 0;
  const hasCategory = !!categoryId && categoryId.length > 0;

  let builder = client
    .from('restaurants')
    .select(hasCategory ? 'id, name, description, logo_url, menu_items!inner(categorie_id)' : 'id, name, description, logo_url');

  if (hasCategory) {
    builder = builder.eq('menu_items.categorie_id', categoryId as string);
  }
  if (hasSearch) {
    builder = builder.ilike('name', `%${trimmedQuery}%`);
  }

  const { data, error } = await builder.order('name').range(offset, offset + limit - 1);
  if (error) throw error;
  return (data ?? []).map(restaurantFromRow);
}
