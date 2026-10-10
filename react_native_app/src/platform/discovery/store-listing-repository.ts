/**
 * Ports `flutter_app/lib/platform/discovery/store_listing_repository.dart`'s
 * `StoreListingRepository` (issue #373 / P4-02).
 *
 * The Dart source injects per-vertical *repository* objects
 * (`RestaurantRepository`/`GroceryRepository`/`PharmacyStoreRepository`),
 * which don't exist in `react_native_app` yet (they land in phases 6/7,
 * issues #382+/#389+) -- not a listed dependency of this issue, but a real
 * gap found reading the Flutter source directly. Rather than block on
 * that, this injects a narrower seam: one async fetcher per vertical that
 * already returns the shared `StoreListing` shape, defaulting to a direct,
 * minimal Supabase query for just the columns a listing needs (mirroring
 * each vertical repository's own query). When the real vertical
 * repositories land, swapping these defaults for calls into them is a
 * same-file change with no effect on this class's public contract or
 * tests.
 */
import { ErrorReporting } from '@/platform/error-reporting/error-reporter';
import {
  electronicsStoreDetails,
  freshMeatStoreDetails,
  groceryStoreDetails,
  pharmacyStoreDetails,
  restaurantDetails,
} from '@/platform/navigation/app-routes';
import { supabase } from '@/platform/supabase/client';
import type { ServiceId } from '@/theme/service-theme';

import type { StoreListing } from './store-listing';

/**
 * A `.from(table).select(...).eq(...).order(...).limit(...)` chain that
 * resolves to `{ data, error }` -- the shape both the real
 * `@supabase/supabase-js` `PostgrestFilterBuilder` and
 * `src/test-utils/fake-supabase-client.ts`'s fake builder share. Narrowed
 * the same way `merchant-role-service.ts`'s `ProfileRoleSource` narrows its
 * own Supabase dependency, so a test can inject the fake instead of the
 * real client.
 */
interface FilterChain<Row> extends PromiseLike<{ data: Row[] | null; error: { message: string } | null }> {
  select(columns: string): FilterChain<Row>;
  eq(column: string, value: unknown): FilterChain<Row>;
  order(column: string, options?: { ascending?: boolean }): FilterChain<Row>;
  limit(count: number): FilterChain<Row>;
}

interface RestaurantRow {
  id: string;
  name: string;
  description: string | null;
  logo_url: string | null;
}

interface GroceryStoreRow {
  id: string;
  name: string;
  area: string;
  image_url: string | null;
  store_type: string;
}

interface PharmacyStoreRow {
  id: string;
  name: string;
  address: string;
  image_url: string | null;
}

export interface StoreListingSource {
  from(table: 'restaurants'): FilterChain<RestaurantRow>;
  from(table: 'grocery_stores'): FilterChain<GroceryStoreRow>;
  from(table: 'pharmacy_stores'): FilterChain<PharmacyStoreRow>;
}

/**
 * Thrown by `fetchStores` when every vertical it queried failed and there
 * is nothing to show at all. Deliberately carries no raw error detail --
 * safe to surface directly in the UI.
 */
export class StoreListingUnavailableException extends Error {
  constructor() {
    super('Stores could not be loaded. Please check your connection and try again.');
    this.name = 'StoreListingUnavailableException';
  }
}

export type VerticalFetch = () => Promise<StoreListing[]>;

export interface StoreListingRepositoryOptions {
  fetchFoodStores?: VerticalFetch;
  fetchGroceryStores?: VerticalFetch;
  fetchPharmacyStores?: VerticalFetch;
  client?: StoreListingSource;
}

interface VerticalResult {
  stores: StoreListing[];
  failed: boolean;
}

export interface FetchStoresOptions {
  /** Omit for all three verticals mixed together; otherwise only that one. */
  filter?: ServiceId;
  /** Caps the total returned count (applied after mixing, not per-vertical). */
  limit?: number;
}

export class StoreListingRepository {
  private readonly fetchFoodStores: VerticalFetch;
  private readonly fetchGroceryStores: VerticalFetch;
  private readonly fetchPharmacyStores: VerticalFetch;

  constructor(options: StoreListingRepositoryOptions = {}) {
    const client = options.client ?? (supabase as unknown as StoreListingSource);
    this.fetchFoodStores = options.fetchFoodStores ?? (() => fetchFoodStoreListings(client));
    this.fetchGroceryStores = options.fetchGroceryStores ?? (() => fetchGroceryStoreListings(client));
    this.fetchPharmacyStores = options.fetchPharmacyStores ?? (() => fetchPharmacyStoreListings(client));
  }

  /**
   * Each vertical's failure is reported individually through
   * `ErrorReporting` rather than silently swallowed. When at least one
   * requested vertical succeeds, this returns whatever loaded. Only when
   * every requested vertical fails does this throw
   * `StoreListingUnavailableException`.
   */
  async fetchStores({ filter, limit }: FetchStoresOptions = {}): Promise<StoreListing[]> {
    let listings: StoreListing[];

    if (!filter) {
      const [food, grocery, pharmacy] = await Promise.all([
        this.runVertical('StoreListingRepository._fetchFood', this.fetchFoodStores),
        this.runVertical('StoreListingRepository._fetchGrocery', this.fetchGroceryStores),
        this.runVertical('StoreListingRepository._fetchPharmacy', this.fetchPharmacyStores),
      ]);
      if (food.failed && grocery.failed && pharmacy.failed) {
        throw new StoreListingUnavailableException();
      }
      listings = interleave([food.stores, grocery.stores, pharmacy.stores]);
    } else if (filter === 'unknown') {
      listings = [];
    } else {
      const [fetch, context] = this.verticalFor(filter);
      const result = await this.runVertical(context, fetch);
      if (result.failed) {
        throw new StoreListingUnavailableException();
      }
      listings = result.stores;
    }

    if (limit === undefined || listings.length <= limit) {
      return listings;
    }
    return listings.slice(0, limit);
  }

  private verticalFor(filter: 'food' | 'grocery' | 'pharmacy'): [VerticalFetch, string] {
    switch (filter) {
      case 'food':
        return [this.fetchFoodStores, 'StoreListingRepository._fetchFood'];
      case 'grocery':
        return [this.fetchGroceryStores, 'StoreListingRepository._fetchGrocery'];
      case 'pharmacy':
        return [this.fetchPharmacyStores, 'StoreListingRepository._fetchPharmacy'];
    }
  }

  private async runVertical(context: string, fetch: VerticalFetch): Promise<VerticalResult> {
    try {
      return { stores: await fetch(), failed: false };
    } catch (error) {
      ErrorReporting.instance.reportError(error, error instanceof Error ? error.stack : undefined, context);
      return { stores: [], failed: true };
    }
  }
}

/**
 * Round-robins across `lists` (one item from each in turn) rather than
 * concatenating them, so a mixed "Popular Stores" section doesn't show
 * every restaurant before the first grocery/pharmacy store just because of
 * fetch order.
 */
function interleave(lists: StoreListing[][]): StoreListing[] {
  const result: StoreListing[] = [];
  let index = 0;
  let remaining = lists.reduce((sum, list) => sum + list.length, 0);
  while (remaining > 0) {
    for (const list of lists) {
      if (index < list.length) {
        result.push(list[index]);
        remaining -= 1;
      }
    }
    index += 1;
  }
  return result;
}

async function fetchFoodStoreListings(client: StoreListingSource): Promise<StoreListing[]> {
  const { data, error } = await client.from('restaurants').select('id, name, description, logo_url').order('name').limit(50);
  if (error) throw error;
  return (data ?? []).map((row) => ({
    id: row.id,
    serviceId: 'food' as const,
    name: row.name,
    subtitle: row.description ?? '',
    imageUrl: row.logo_url && row.logo_url.length > 0 ? row.logo_url : null,
    route: restaurantDetails(row.id),
  }));
}

async function fetchGroceryStoreListings(client: StoreListingSource): Promise<StoreListing[]> {
  const { data, error } = await client
    .from('grocery_stores')
    .select('id, name, area, image_url, store_type')
    .eq('is_active', true)
    .order('name')
    .limit(30);
  if (error) throw error;
  return (data ?? []).map((row) => ({
    id: row.id,
    serviceId: 'grocery' as const,
    name: row.name,
    subtitle: row.area,
    imageUrl: row.image_url,
    route: groceryStoreDetailsForType(row.store_type, row.id),
  }));
}

/** Mirrors `GroceryStoreType.fromDb(...).storeDetailsRoute(storeId)`. */
function groceryStoreDetailsForType(storeType: string, storeId: string): string {
  switch (storeType) {
    case 'fresh_meat':
      return freshMeatStoreDetails(storeId);
    case 'electronics':
      return electronicsStoreDetails(storeId);
    default:
      return groceryStoreDetails(storeId);
  }
}

async function fetchPharmacyStoreListings(client: StoreListingSource): Promise<StoreListing[]> {
  const { data, error } = await client
    .from('pharmacy_stores')
    .select('id, name, address, image_url')
    .eq('is_active', true)
    .order('name');
  if (error) throw error;
  return (data ?? []).map((row) => ({
    id: row.id,
    serviceId: 'pharmacy' as const,
    name: row.name,
    subtitle: row.address,
    imageUrl: row.image_url,
    route: pharmacyStoreDetails(row.id),
  }));
}
