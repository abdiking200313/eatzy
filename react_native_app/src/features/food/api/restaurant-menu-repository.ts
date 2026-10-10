/**
 * Ports `flutter_app/lib/services/food/data/restaurant_menu_repository.dart`'s
 * `RestaurantMenuRepository.fetchMenu` (issue #383) -- see
 * `category-repository.ts`'s top comment for why this is a free function
 * with an injectable client rather than Dart's constructor-injected class.
 */
import { ErrorReporting } from '@/platform/error-reporting/error-reporter';
import { supabase } from '@/platform/supabase/client';

import {
  InvalidMenuItemPriceError,
  menuItemFromRow,
  type MenuCategory,
  type MenuItem,
  type MenuItemRow,
  type RestaurantMenu,
} from './restaurant-menu';
import { restaurantFromRow, type RestaurantRow } from './restaurant';

/**
 * The slice of `supabase` {@link fetchMenu} depends on -- narrowed the same
 * way `RestaurantSource`/`CategorySource` narrow their own Supabase
 * dependency (see `restaurant-repository.ts`), so a test can inject a fake
 * instead of the real client. Two separate chains since `restaurants` is
 * read with `.single()` and `menu_items` is read as a list.
 */
export interface RestaurantMenuSource {
  from(table: 'restaurants'): RestaurantSingleChain;
  from(table: 'menu_items'): MenuItemsChain;
}

interface RestaurantSingleChain {
  select(columns: string): RestaurantSingleChain;
  eq(column: string, value: unknown): RestaurantSingleChain;
  single(): PromiseLike<{ data: RestaurantRow | null; error: { message: string } | null }>;
}

interface MenuItemsChain {
  select(columns: string): MenuItemsChain;
  eq(column: string, value: unknown): MenuItemsChain;
  order(column: string): PromiseLike<{ data: MenuItemRow[] | null; error: { message: string } | null }>;
}

/**
 * Fetches one restaurant's menu: the restaurant's own display fields plus
 * every `menu_items` row for it, grouped into {@link MenuCategory}s. Mirrors
 * the Dart repository's `fetchMenu` exactly, including running both queries
 * concurrently (`Future.wait`/`Promise.all`) and per-item price-parsing
 * failures excluding just that item rather than failing the whole menu --
 * see `restaurant-menu.ts`'s `InvalidMenuItemPriceError` doc comment.
 */
export async function fetchMenu(
  restaurantId: string,
  client: RestaurantMenuSource = supabase as unknown as RestaurantMenuSource,
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
  if (!restaurantResult.data) {
    throw new Error(`Restaurant not found: ${restaurantId}`);
  }
  if (itemsResult.error) throw itemsResult.error;

  return {
    restaurant: restaurantFromRow(restaurantResult.data),
    categories: groupItemsByCategory(itemsResult.data ?? []),
  };
}

/** Mirrors `RestaurantMenuRepository._groupItemsByCategory`. */
function groupItemsByCategory(rows: MenuItemRow[]): MenuCategory[] {
  const categoryNames = new Map<string, string>();
  const groupedItems = new Map<string, MenuItem[]>();

  for (const row of rows) {
    let item: MenuItem;
    try {
      item = menuItemFromRow(row);
    } catch (error) {
      if (error instanceof InvalidMenuItemPriceError) {
        // Exclude just this item rather than failing the whole menu load --
        // a bad price must never fall back to $0.00 (a real charge with no
        // on-screen warning), but nor should it block every other item on
        // the menu from being shown.
        ErrorReporting.instance.reportError(error, error.stack, 'fetchMenu.groupItemsByCategory');
        continue;
      }
      throw error;
    }

    const category = row.item_categories;
    const categoryEntry = Array.isArray(category) ? category[0] : category;
    const categoryName = categoryEntry?.name?.trim();

    categoryNames.set(item.categoryId, categoryName && categoryName.length > 0 ? categoryName : 'Other');
    const items = groupedItems.get(item.categoryId) ?? [];
    items.push(item);
    groupedItems.set(item.categoryId, items);
  }

  const categories: MenuCategory[] = Array.from(groupedItems.entries()).map(([id, items]) => ({
    id,
    name: categoryNames.get(id) ?? 'Other',
    items,
  }));

  categories.sort((a, b) => {
    if (a.name === 'Other') return 1;
    if (b.name === 'Other') return -1;
    return a.name.toLowerCase().localeCompare(b.name.toLowerCase());
  });

  return categories;
}
