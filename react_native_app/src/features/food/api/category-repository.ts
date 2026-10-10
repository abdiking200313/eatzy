/**
 * Ports `flutter_app/lib/services/food/data/category_repository.dart`'s
 * `CategoryRepository.fetchCategories` (issue #382).
 *
 * Follows the free-function + injectable-client convention already used by
 * `src/platform/activity/api/activity-repository.ts`'s `fetchActivities`
 * and `src/platform/discovery/store-listing-repository.ts`'s
 * `fetchFoodStoreListings` (a narrow `*Source` interface, structurally
 * satisfied by both the real `supabase` client and
 * `src/test-utils/fake-supabase-client.ts`) rather than Dart's
 * constructor-injected class, since nothing here needs to hold state
 * between calls.
 */
import { supabase } from '@/platform/supabase/client';

import { categoryFromRow, type Category, type CategoryRow } from './category';

/**
 * Default page size for the unbounded category list.
 *
 * The home screen does not yet page through categories, so this only
 * bounds the worst case. A real pagination contract is left as a
 * follow-up -- mirrors the Dart repository's own `defaultPageSize` comment.
 */
export const CATEGORY_DEFAULT_PAGE_SIZE = 50;

/**
 * The slice of `supabase` {@link fetchCategories} depends on, narrowed the
 * same way `ActivitySource`/`StoreListingSource` narrow their own Supabase
 * dependency -- lets a test inject a fake instead of the real client.
 */
export interface CategorySource {
  from(table: 'item_categories'): {
    select(columns: string): {
      order(column: string): {
        range(
          from: number,
          to: number,
        ): PromiseLike<{ data: CategoryRow[] | null; error: { message: string } | null }>;
      };
    };
  };
}

export interface FetchCategoriesOptions {
  limit?: number;
  offset?: number;
}

/** Fetches categories, bounded to `limit` rows starting at `offset`. */
export async function fetchCategories(
  { limit = CATEGORY_DEFAULT_PAGE_SIZE, offset = 0 }: FetchCategoriesOptions = {},
  client: CategorySource = supabase as unknown as CategorySource,
): Promise<Category[]> {
  const { data, error } = await client
    .from('item_categories')
    .select('id, name, icon_url')
    .order('name')
    .range(offset, offset + limit - 1);
  if (error) throw error;
  return (data ?? []).map(categoryFromRow);
}
