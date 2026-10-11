/**
 * Ports `flutter_app/lib/features/merchant/catalog/data/merchant_catalog_repository.dart`
 * (issue #410 / P9-05): data access for the signed-in merchant's own catalog
 * items in `menu_items` / `grocery_products` / `pharmacy_products`.
 *
 * Ownership is enforced server-side by RLS, inherited from the parent
 * store's `owner_id` (these item tables have no `owner_id` of their own --
 * see `supabase/migrations/20260830130000_add_merchant_catalog_write_policies.sql`).
 * RN addition: every update/delete is also scoped client-side to the item's
 * own store column, belt-and-braces on top of that RLS predicate (the same
 * approach `merchant-store-repository.ts` takes with `owner_id`).
 *
 * These are the very tables the customer catalogs read
 * (`restaurant-menu-repository.ts`, `grocery-repository.ts`,
 * `pharmacy-repository.ts`), so a created/edited item is what customers see.
 */
import { supabase } from '@/platform/supabase/client';

import { generateMerchantSlugId } from '../../shared/merchant-slug-id';
import { MERCHANT_VERTICAL_CONFIG, type MerchantVertical } from '../../store/api/merchant-vertical';
import {
  GROCERY_REQUIRED_QUANTITY_STEP,
  merchantCatalogItemFromRow,
  pharmacyCategoryFromRow,
  type MerchantCatalogItem,
  type PharmacyCategory,
} from './merchant-catalog-item';

type Row = Record<string, unknown>;
type SupabaseResult<T> = { data: T | null; error: unknown };

interface CatalogFilterChain extends PromiseLike<SupabaseResult<unknown>> {
  eq(column: string, value: unknown): CatalogFilterChain;
  select(columns: string): CatalogFilterChain;
  order(column: string): CatalogFilterChain;
  limit(count: number): CatalogFilterChain;
  single(): PromiseLike<SupabaseResult<Row>>;
}

/**
 * The slice of `supabase` {@link SupabaseMerchantCatalogRepository} depends
 * on, so a test can inject `src/test-utils/fake-supabase-client.ts`.
 */
export interface MerchantCatalogSource {
  from(table: string): {
    select(columns: string): CatalogFilterChain;
    insert(values: Row): CatalogFilterChain;
    update(values: Row): CatalogFilterChain;
    delete(): CatalogFilterChain;
  };
}

/** Mirrors the Dart `FormatException`s thrown for a blank name / missing pharmacy category. */
export class MerchantCatalogValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'MerchantCatalogValidationError';
  }
}

export interface MerchantCatalogRepository {
  /**
   * Every item belonging to `storeId` in `vertical`, regardless of
   * availability -- unlike the customer reads, a merchant needs to see
   * unavailable items too so they can re-enable them.
   */
  fetchItems(args: { vertical: MerchantVertical; storeId: string }): Promise<MerchantCatalogItem[]>;
  createItem(draft: MerchantCatalogItem): Promise<MerchantCatalogItem>;
  updateItem(item: MerchantCatalogItem): Promise<MerchantCatalogItem>;
  deleteItem(item: MerchantCatalogItem): Promise<void>;
  setAvailability(args: { item: MerchantCatalogItem; isAvailable: boolean }): Promise<MerchantCatalogItem>;
  /** Active pharmacy categories (public data), for the required category picker. */
  fetchPharmacyCategories(): Promise<PharmacyCategory[]>;
}

/** Mirrors `SupabaseMerchantCatalogRepository.maxItemsPerStore`. */
export const MAX_ITEMS_PER_STORE = 500;

function selectColumns(vertical: MerchantVertical): string {
  const config = MERCHANT_VERTICAL_CONFIG[vertical];
  return [
    'id',
    'name',
    'description',
    config.itemPriceColumn,
    config.itemAvailableColumn,
    'image_url',
    ...(vertical === 'grocery' ? ['pricing_unit', 'available_quantity'] : []),
    ...(vertical === 'pharmacy' ? ['category_id', 'stock_quantity'] : []),
  ].join(', ');
}

function nullIfBlank(value: string | null | undefined): string | null {
  const trimmed = value?.trim() ?? '';
  return trimmed.length === 0 ? null : trimmed;
}

function requireName(item: MerchantCatalogItem): void {
  if (item.name.trim().length === 0) {
    throw new MerchantCatalogValidationError('An item name is required.');
  }
}

function unwrap<T>({ data, error }: SupabaseResult<T>): T {
  if (error) throw error;
  if (data == null) throw new Error('The catalog row was not returned.');
  return data;
}

/** Mirrors `_writablePayload`. */
function writablePayload(item: MerchantCatalogItem): Row {
  const config = MERCHANT_VERTICAL_CONFIG[item.vertical];
  const payload: Row = {
    name: item.name.trim(),
    description: item.description?.trim() ?? '',
    [config.itemPriceColumn]: item.priceCents,
    [config.itemAvailableColumn]: item.isAvailable,
    image_url: nullIfBlank(item.imageUrl),
  };

  if (item.vertical === 'grocery') {
    const pricingUnit = item.pricingUnit ?? 'each';
    payload.pricing_unit = pricingUnit;
    // `quantity_step` has no default and its check constraint ties it to
    // `pricing_unit`, so both are always written together.
    payload.quantity_step = GROCERY_REQUIRED_QUANTITY_STEP[pricingUnit];
    payload.available_quantity = item.availableQuantity ?? 0;
  }

  if (item.vertical === 'pharmacy') {
    const categoryId = item.categoryId?.trim() ?? '';
    if (categoryId.length === 0) {
      throw new MerchantCatalogValidationError('A pharmacy product needs a category.');
    }
    payload.category_id = item.categoryId;
    payload.stock_quantity = item.stockQuantity ?? 0;
    // `sale_type` is left to its column default (`'otc'`, the only value
    // its check constraint allows).
  }

  return payload;
}

export class SupabaseMerchantCatalogRepository implements MerchantCatalogRepository {
  private readonly client: MerchantCatalogSource;

  constructor(client: MerchantCatalogSource = supabase as unknown as MerchantCatalogSource) {
    this.client = client;
  }

  async fetchItems({ vertical, storeId }: { vertical: MerchantVertical; storeId: string }): Promise<MerchantCatalogItem[]> {
    const config = MERCHANT_VERTICAL_CONFIG[vertical];
    const result = await this.client
      .from(config.itemTable)
      .select(selectColumns(vertical))
      .eq(config.itemStoreColumn, storeId)
      .order('name')
      .limit(MAX_ITEMS_PER_STORE);
    if (result.error) throw result.error;
    const rows = (result.data as Row[] | null) ?? [];
    return rows.map((row) => merchantCatalogItemFromRow(row, { vertical, storeId }));
  }

  async createItem(draft: MerchantCatalogItem): Promise<MerchantCatalogItem> {
    requireName(draft);
    const { vertical, storeId } = draft;
    const config = MERCHANT_VERTICAL_CONFIG[vertical];
    const payload: Row = { ...writablePayload(draft), [config.itemStoreColumn]: storeId };
    if (!config.itemIdIsServerGenerated) {
      payload.id = generateMerchantSlugId(draft.name);
    }

    const result = await this.client.from(config.itemTable).insert(payload).select(selectColumns(vertical)).single();
    return merchantCatalogItemFromRow(unwrap(result), { vertical, storeId });
  }

  async updateItem(item: MerchantCatalogItem): Promise<MerchantCatalogItem> {
    requireName(item);
    const { vertical, storeId } = item;
    const config = MERCHANT_VERTICAL_CONFIG[vertical];
    const result = await this.client
      .from(config.itemTable)
      .update(writablePayload(item))
      .eq('id', item.id)
      .eq(config.itemStoreColumn, storeId)
      .select(selectColumns(vertical))
      .single();
    return merchantCatalogItemFromRow(unwrap(result), { vertical, storeId });
  }

  async deleteItem(item: MerchantCatalogItem): Promise<void> {
    const config = MERCHANT_VERTICAL_CONFIG[item.vertical];
    const { error } = await this.client
      .from(config.itemTable)
      .delete()
      .eq('id', item.id)
      .eq(config.itemStoreColumn, item.storeId);
    if (error) throw error;
  }

  async setAvailability({ item, isAvailable }: { item: MerchantCatalogItem; isAvailable: boolean }): Promise<MerchantCatalogItem> {
    const { vertical, storeId } = item;
    const config = MERCHANT_VERTICAL_CONFIG[vertical];
    const result = await this.client
      .from(config.itemTable)
      .update({ [config.itemAvailableColumn]: isAvailable })
      .eq('id', item.id)
      .eq(config.itemStoreColumn, storeId)
      .select(selectColumns(vertical))
      .single();
    return merchantCatalogItemFromRow(unwrap(result), { vertical, storeId });
  }

  async fetchPharmacyCategories(): Promise<PharmacyCategory[]> {
    const result = await this.client.from('pharmacy_categories').select('id, name').eq('is_active', true).order('name');
    if (result.error) throw result.error;
    const rows = (result.data as Row[] | null) ?? [];
    return rows.map(pharmacyCategoryFromRow);
  }
}
