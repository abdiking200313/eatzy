/**
 * Ports `flutter_app/lib/services/pharmacy/data/pharmacy_repository.dart`'s
 * catalog/store-list reads (issue #394 / P7-06):
 * `SupabasePharmacyCatalogRepository` (`fetchCategories`/`fetchProducts`),
 * `SupabasePharmacyStoreRepository.fetchStores`, and the in-memory
 * `SeededPharmacyRepository` the Flutter tests (and this port's tests) use.
 *
 * `SupabasePharmacyOrderRepository` (`place_pharmacy_order`) is ported in
 * `pharmacy-order-repository.ts` (issue #395).
 *
 * Like `grocery-repository.ts`, the Supabase dependency is narrowed to the
 * `from(...)` chain this module actually uses so a test can inject
 * `src/test-utils/fake-supabase-client.ts` instead of the real client.
 */
import { supabase } from '@/platform/supabase/client';

import {
  pharmacyCategoryFromRow,
  pharmacyProductFromRow,
  pharmacyStoreFromRow,
  type PharmacyCategory,
  type PharmacyCategoryRow,
  type PharmacyProduct,
  type PharmacyProductRow,
  type PharmacyStore,
  type PharmacyStoreRow,
} from './pharmacy-models';

/**
 * Mirrors `pharmacyProductsPageSize`: the default page size for
 * `fetchProducts`. A result page shorter than this signals the end of the
 * catalog to callers doing infinite scroll.
 */
export const PHARMACY_PRODUCTS_PAGE_SIZE = 30;

export interface FetchPharmacyProductsOptions {
  /** The pharmacy (`pharmacy_stores.id`) whose catalog to fetch. Products are always scoped to one pharmacy at a time. */
  storeId: string;
  /** Case-insensitive product-name substring match. */
  searchQuery?: string | null;
  limit?: number;
  offset?: number;
}

/** Ports `PharmacyRepository`: the seam the catalog store loads products through. */
export interface PharmacyRepository {
  fetchProducts(options: FetchPharmacyProductsOptions): Promise<PharmacyProduct[]>;
}

/** Ports `PharmacyCatalogRepository`. */
export interface PharmacyCatalogRepository extends PharmacyRepository {
  fetchCategories(): Promise<PharmacyCategory[]>;
}

interface FilterChain<Row> extends PromiseLike<{ data: Row[] | null; error: { message: string } | null }> {
  select(columns: string): FilterChain<Row>;
  eq(column: string, value: unknown): FilterChain<Row>;
  ilike(column: string, pattern: string): FilterChain<Row>;
  order(column: string): FilterChain<Row>;
  range(from: number, to: number): FilterChain<Row>;
}

export interface PharmacySource {
  from(table: 'pharmacy_stores'): FilterChain<PharmacyStoreRow>;
  from(table: 'pharmacy_products'): FilterChain<PharmacyProductRow>;
  from(table: 'pharmacy_categories'): FilterChain<PharmacyCategoryRow>;
}

function defaultSource(): PharmacySource {
  return supabase as unknown as PharmacySource;
}

function normalizeSearch(searchQuery: string | null | undefined): string | null {
  const trimmed = searchQuery?.trim();
  return trimmed ? trimmed : null;
}

const PRODUCT_COLUMNS =
  'id, name, description, unit_price, stock_quantity, sale_type, image_url, store_id, pharmacy_categories!inner(id, name)';

/** Ports `SupabasePharmacyCatalogRepository`. */
export function createSupabasePharmacyCatalogRepository(client: PharmacySource = defaultSource()): PharmacyCatalogRepository {
  return {
    async fetchCategories() {
      const { data, error } = await client.from('pharmacy_categories').select('id, name').eq('is_active', true).order('name');
      if (error) throw error;
      return (data ?? []).map(pharmacyCategoryFromRow);
    },

    async fetchProducts({ storeId, searchQuery, limit = PHARMACY_PRODUCTS_PAGE_SIZE, offset = 0 }) {
      const query = normalizeSearch(searchQuery);
      let builder = client
        .from('pharmacy_products')
        .select(PRODUCT_COLUMNS)
        .eq('is_active', true)
        .eq('sale_type', 'otc')
        .eq('store_id', storeId)
        .eq('pharmacy_categories.is_active', true);
      if (query) {
        builder = builder.ilike('name', `%${query}%`);
      }

      const { data, error } = await builder.order('name').range(offset, offset + limit - 1);
      if (error) throw error;
      return (data ?? []).map(pharmacyProductFromRow).filter((product) => product.saleType === 'overTheCounter');
    },
  };
}

/**
 * Ports `SupabasePharmacyStoreRepository.fetchStores`: active pharmacies,
 * optionally narrowed by a case-insensitive name substring match.
 */
export async function fetchPharmacyStores(
  searchQuery?: string | null,
  client: PharmacySource = defaultSource(),
): Promise<PharmacyStore[]> {
  const query = normalizeSearch(searchQuery);
  let builder = client.from('pharmacy_stores').select('id, name, address, image_url').eq('is_active', true);
  if (query) {
    builder = builder.ilike('name', `%${query}%`);
  }
  const { data, error } = await builder.order('name');
  if (error) throw error;
  return (data ?? []).map(pharmacyStoreFromRow);
}

/** Mirrors `SeededPharmacyRepository.defaultStoreId`. */
export const SEEDED_PHARMACY_STORE_ID = 'legacy-pharmacy';

/** Mirrors `SeededPharmacyRepository.products`. */
export const SEEDED_PHARMACY_PRODUCTS: readonly PharmacyProduct[] = [
  {
    id: 'pain-paracetamol',
    storeId: SEEDED_PHARMACY_STORE_ID,
    name: 'Paracetamol',
    description: 'Everyday relief for mild pain and fever.',
    category: 'Pain relief',
    unitPrice: 275,
    stockQuantity: 24,
    saleType: 'overTheCounter',
  },
  {
    id: 'cold-cough-syrup',
    storeId: SEEDED_PHARMACY_STORE_ID,
    name: 'Cough Syrup',
    description: 'Soothing syrup for common cough symptoms.',
    category: 'Cold & flu',
    unitPrice: 550,
    stockQuantity: 4,
    saleType: 'overTheCounter',
  },
  {
    id: 'first-aid-bandages',
    storeId: SEEDED_PHARMACY_STORE_ID,
    name: 'Adhesive Bandages',
    description: 'A pack of 30 sterile everyday bandages.',
    category: 'First aid',
    unitPrice: 325,
    stockQuantity: 18,
    saleType: 'overTheCounter',
  },
  {
    id: 'wellness-vitamin-c',
    storeId: SEEDED_PHARMACY_STORE_ID,
    name: 'Vitamin C',
    description: 'Thirty 500 mg vitamin C tablets.',
    category: 'Vitamins',
    unitPrice: 600,
    stockQuantity: 10,
    saleType: 'overTheCounter',
  },
  {
    id: 'allergy-antihistamine',
    storeId: SEEDED_PHARMACY_STORE_ID,
    name: 'Allergy Relief',
    description: 'Non-drowsy tablets for common allergy symptoms.',
    category: 'Allergy',
    unitPrice: 480,
    stockQuantity: 0,
    saleType: 'overTheCounter',
  },
];

/**
 * Ports `SeededPharmacyRepository`: an in-memory {@link PharmacyRepository}
 * over `products` (defaulting to {@link SEEDED_PHARMACY_PRODUCTS}), with the
 * same store-scoping, case-insensitive name search, and offset/limit paging
 * as the Supabase query. Mainly a test fixture, as in the Dart source.
 */
export function createInMemoryPharmacyRepository(
  products: readonly PharmacyProduct[] = SEEDED_PHARMACY_PRODUCTS,
): PharmacyRepository {
  return {
    async fetchProducts({ storeId, searchQuery, limit = PHARMACY_PRODUCTS_PAGE_SIZE, offset = 0 }) {
      const query = searchQuery?.trim().toLowerCase();
      const matches = products
        .filter((product) => product.storeId === storeId)
        .filter((product) => !query || product.name.toLowerCase().includes(query));
      if (offset >= matches.length) {
        return [];
      }
      return matches.slice(offset, Math.min(offset + limit, matches.length));
    },
  };
}
