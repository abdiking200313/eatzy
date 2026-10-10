/**
 * Ports `flutter_app/lib/services/grocery/data/grocery_repository.dart`'s
 * `SupabaseGroceryCatalogRepository.fetchStores` (issue #389 / P7-01) --
 * the every-store-at-once read the grocery/Fresh Meat/Electronics store
 * *list* screens use (not `fetchStore`/`fetchDeliverySlots`, which belong
 * to the single-store screen landing in a later issue).
 *
 * See `features/food/api/restaurant-repository.ts` for why this is a free
 * function with an injectable client rather than a Dart-style
 * constructor-injected class.
 */
import { supabase } from '@/platform/supabase/client';

import { groceryProductFromRow, groceryStoreFromRow, type GroceryProductRow, type GroceryStore, type GroceryStoreRow } from './grocery-store';

/** Mirrors `SupabaseGroceryCatalogRepository.maxStores`. */
export const GROCERY_MAX_STORES = 30;
/** Mirrors `SupabaseGroceryCatalogRepository.maxProducts`. */
export const GROCERY_MAX_PRODUCTS = 300;

const STORE_COLUMNS = 'id, name, area, image_url, store_type';
const PRODUCT_COLUMNS =
  'id, store_id, name, description, unit_price, pricing_unit, quantity_step, available_quantity, low_stock_threshold, icon, image_url, grocery_categories(name, sort_order)';

interface FilterChain<Row> extends PromiseLike<{ data: Row[] | null; error: { message: string } | null }> {
  select(columns: string): FilterChain<Row>;
  eq(column: string, value: unknown): FilterChain<Row>;
  order(column: string): FilterChain<Row>;
  limit(count: number): FilterChain<Row>;
}

export interface GroceryStoreSource {
  from(table: 'grocery_stores'): FilterChain<GroceryStoreRow>;
  from(table: 'grocery_products'): FilterChain<GroceryProductRow>;
}

/**
 * Fetches every active grocery store (across all three `GroceryStoreType`s)
 * with its own products grouped on, bounded the same way the Dart source
 * bounds its worst case ({@link GROCERY_MAX_STORES}/{@link GROCERY_MAX_PRODUCTS}).
 * Filtering down to one `GroceryStoreType` happens client-side afterward --
 * mirrors `GroceryCatalog.load()`, which fetches unfiltered then filters by
 * `storeType` in memory.
 */
export async function fetchGroceryStores(client: GroceryStoreSource = supabase as unknown as GroceryStoreSource): Promise<GroceryStore[]> {
  const [storesResult, productsResult] = await Promise.all([
    client.from('grocery_stores').select(STORE_COLUMNS).eq('is_active', true).order('name').limit(GROCERY_MAX_STORES),
    client.from('grocery_products').select(PRODUCT_COLUMNS).eq('is_active', true).order('name').limit(GROCERY_MAX_PRODUCTS),
  ]);

  if (storesResult.error) throw storesResult.error;
  if (productsResult.error) throw productsResult.error;

  const productsByStore = new Map<string, ReturnType<typeof groceryProductFromRow>[]>();
  for (const row of productsResult.data ?? []) {
    const product = groceryProductFromRow(row);
    const existing = productsByStore.get(product.storeId);
    if (existing) {
      existing.push(product);
    } else {
      productsByStore.set(product.storeId, [product]);
    }
  }

  return (storesResult.data ?? []).map((row) => groceryStoreFromRow(row, productsByStore.get(row.id) ?? []));
}
