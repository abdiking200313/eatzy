/**
 * Ports `flutter_app/lib/services/food/data/restaurant_menu_repository.dart`'s
 * `RestaurantMenuRepository.fetchMenu` (issue #383). Same free-function +
 * injectable-client convention as `restaurant-repository.ts`/
 * `category-repository.ts`.
 */
import { ErrorReporting, type ErrorReporter } from '@/platform/error-reporting/error-reporter';
import { supabase } from '@/platform/supabase/client';

import { restaurantFromRow, type RestaurantRow } from './restaurant';
import {
  MenuItemFormatError,
  menuItemFromRow,
  type MenuCategory,
  type MenuItem,
  type MenuItemRow,
  type RestaurantMenu,
} from './restaurant-menu';

type QueryResult<T> = PromiseLike<{ data: T | null; error: { message: string } | null }>;

/** The slice of `supabase` {@link fetchRestaurantMenu} depends on -- see `CategorySource`'s doc comment. */
export interface RestaurantMenuSource {
  from(table: 'restaurants'): {
    select(columns: string): { eq(column: string, value: string): { single(): QueryResult<RestaurantRow> } };
  };
  from(table: 'menu_items'): {
    select(columns: string): { eq(column: string, value: string): { order(column: string): QueryResult<MenuItemRow[]> } };
  };
}

/** The category name/sort key used for items with no (or a blank) category -- mirrors the Dart `'Other'` literal. */
export const OTHER_CATEGORY_NAME = 'Other';

/**
 * Fetches the restaurant row and its menu items in parallel, then groups
 * the items by category. Mirrors `fetchMenu`'s `Future.wait` pair.
 */
export async function fetchRestaurantMenu(
  restaurantId: string,
  client: RestaurantMenuSource = supabase as unknown as RestaurantMenuSource,
  reporter: ErrorReporter = ErrorReporting.instance,
): Promise<RestaurantMenu> {
  const [restaurantResult, itemsResult] = await Promise.all([
    client.from('restaurants').select('id, name, description, logo_url').eq('id', restaurantId).single(),
    client
      .from('menu_items')
      .select('id, name, description, price, image_url, categorie_id, item_categories(id, name)')
      .eq('restaurant_id', restaurantId)
      .order('name'),
  ]);

  if (restaurantResult.error) throw restaurantResult.error;
  if (itemsResult.error) throw itemsResult.error;
  if (!restaurantResult.data) throw new Error(`Restaurant ${restaurantId} not found`);

  return {
    restaurant: restaurantFromRow(restaurantResult.data),
    categories: groupMenuItemsByCategory(itemsResult.data ?? [], reporter),
  };
}

/**
 * Ports `_groupItemsByCategory`: groups rows by `categorie_id`, names each
 * group from its joined `item_categories.name` (blank/missing -> 'Other'),
 * and sorts groups by name case-insensitively with 'Other' always last.
 * A row with an invalid price is reported and skipped rather than failing
 * the whole menu.
 */
export function groupMenuItemsByCategory(
  rows: MenuItemRow[],
  reporter: ErrorReporter = ErrorReporting.instance,
): MenuCategory[] {
  const categoryNames = new Map<string, string>();
  const groupedItems = new Map<string, MenuItem[]>();

  for (const row of rows) {
    let item: MenuItem;
    try {
      item = menuItemFromRow(row);
    } catch (error) {
      if (!(error instanceof MenuItemFormatError)) throw error;
      reporter.reportError(error, error.stack, 'fetchRestaurantMenu.groupMenuItemsByCategory');
      continue;
    }

    const category = row.item_categories;
    const categoryName = category && typeof category === 'object' ? category.name?.toString().trim() : undefined;
    categoryNames.set(item.categoryId, categoryName ? categoryName : OTHER_CATEGORY_NAME);

    const items = groupedItems.get(item.categoryId);
    if (items) {
      items.push(item);
    } else {
      groupedItems.set(item.categoryId, [item]);
    }
  }

  const categories: MenuCategory[] = [...groupedItems.entries()].map(([id, items]) => ({
    id,
    name: categoryNames.get(id) ?? OTHER_CATEGORY_NAME,
    items,
  }));

  categories.sort((a, b) => {
    // Two 'Other' groups keep their first-seen order (the Dart comparator
    // returns 1 for both orderings, which is inconsistent; this is stable).
    if (a.name === OTHER_CATEGORY_NAME && b.name === OTHER_CATEGORY_NAME) return 0;
    if (a.name === OTHER_CATEGORY_NAME) return 1;
    if (b.name === OTHER_CATEGORY_NAME) return -1;
    const left = a.name.toLowerCase();
    const right = b.name.toLowerCase();
    return left < right ? -1 : left > right ? 1 : 0;
  });

  return categories;
}
