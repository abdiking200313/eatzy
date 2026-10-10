/**
 * Ports the catalog-loading slice of
 * `flutter_app/lib/services/pharmacy/presentation/pharmacy_controller.dart`
 * (`PharmacyController.loadProducts`/`loadMore`/`isStale` plus the
 * `LoadableState` mixin's `isLoading`/`loadError`) -- issue #394 / P7-06.
 *
 * The cart half of `PharmacyController` was already ported to
 * `src/stores/pharmacy-cart-store.ts` (issue #376); checkout
 * (`placeDemoOrder`) belongs to a later issue. This keeps the Dart
 * controller's own hand-rolled staleness/scope/paging rules (rather than
 * re-expressing them through TanStack Query) so
 * `pharmacy_controller_test.dart`'s catalog cases port one-to-one.
 */
import { create, type StoreApi, type UseBoundStore } from 'zustand';

import { isPharmacyProductOverTheCounter, type PharmacyProduct } from '@/stores/pharmacy-cart-store';

import {
  createSupabasePharmacyCatalogRepository,
  PHARMACY_PRODUCTS_PAGE_SIZE,
  type PharmacyRepository,
} from './api/pharmacy-repository';

/**
 * Mirrors `PharmacyController.catalogStaleAfter` (5 minutes): how long a
 * successful load is considered fresh before `loadProducts` will silently
 * refetch the same scope again. `forceRefresh` always bypasses this.
 */
export const PHARMACY_CATALOG_STALE_AFTER_MS = 5 * 60 * 1000;

/** Mirrors the `onError` message `PharmacyController.loadProducts` passes to `runLoad`. */
export const PHARMACY_CATALOG_LOAD_ERROR = 'The pharmacy catalog could not be loaded.';

export interface LoadPharmacyProductsOptions {
  storeId: string;
  searchQuery?: string | null;
  forceRefresh?: boolean;
}

export interface PharmacyCatalogState {
  products: PharmacyProduct[];
  isLoading: boolean;
  loadError: string | null;
  isLoadingMore: boolean;
  /** Whether another page may exist. Starts `true`; flips to `false` once a page comes back shorter than the page size. */
  hasMore: boolean;
  /** The pharmacy currently loaded into `products`, or `null` before the first load. */
  currentStoreId: string | null;
  currentSearchQuery: string | null;
  lastLoadedAt: number | null;
  /** Ports `PharmacyController.isStale`: never loaded, or last loaded at least {@link PHARMACY_CATALOG_STALE_AFTER_MS} ago. */
  isStale: () => boolean;
  /** Ports `PharmacyController.loadProducts` -- see its doc comment for the no-op/refetch rules. */
  loadProducts: (options: LoadPharmacyProductsOptions) => Promise<void>;
  /** Ports `PharmacyController.loadMore`. */
  loadMore: () => Promise<void>;
}

export interface CreatePharmacyCatalogStoreOptions {
  /** Defaults to the Supabase-backed catalog repository (`SupabasePharmacyCatalogRepository` in the Dart app's `AppServices`). */
  repository?: PharmacyRepository;
  /** Clock seam, mirroring the Dart controller's `now` parameter. Returns epoch milliseconds. */
  now?: () => number;
}

export type PharmacyCatalogStore = UseBoundStore<StoreApi<PharmacyCatalogState>>;

function normalizeSearchQuery(searchQuery: string | null | undefined): string | null {
  const trimmed = searchQuery?.trim();
  return trimmed ? trimmed : null;
}

/** Builds an independent catalog store -- tests build their own; the app renders against {@link usePharmacyCatalogStore}. */
export function createPharmacyCatalogStore(options: CreatePharmacyCatalogStoreOptions = {}): PharmacyCatalogStore {
  const repository = options.repository ?? createSupabasePharmacyCatalogRepository();
  const now = options.now ?? Date.now;

  return create<PharmacyCatalogState>((set, get) => ({
    products: [],
    isLoading: false,
    loadError: null,
    isLoadingMore: false,
    hasMore: true,
    currentStoreId: null,
    currentSearchQuery: null,
    lastLoadedAt: null,

    isStale: () => {
      const { lastLoadedAt } = get();
      return lastLoadedAt == null || now() - lastLoadedAt >= PHARMACY_CATALOG_STALE_AFTER_MS;
    },

    loadProducts: async ({ storeId, searchQuery, forceRefresh = false }) => {
      const state = get();
      if (state.isLoading) {
        return;
      }
      const normalizedQuery = normalizeSearchQuery(searchQuery);
      const scopeChanged = storeId !== state.currentStoreId || normalizedQuery !== state.currentSearchQuery;
      if (!forceRefresh && !scopeChanged && state.products.length > 0 && !state.isStale()) {
        return;
      }

      set({ isLoading: true, loadError: null });
      try {
        const products = await repository.fetchProducts({
          storeId,
          searchQuery: normalizedQuery,
          limit: PHARMACY_PRODUCTS_PAGE_SIZE,
        });
        set({
          products: products.filter(isPharmacyProductOverTheCounter),
          hasMore: products.length >= PHARMACY_PRODUCTS_PAGE_SIZE,
          lastLoadedAt: now(),
          currentStoreId: storeId,
          currentSearchQuery: normalizedQuery,
        });
      } catch {
        set({ loadError: PHARMACY_CATALOG_LOAD_ERROR });
      } finally {
        set({ isLoading: false });
      }
    },

    loadMore: async () => {
      const state = get();
      const storeId = state.currentStoreId;
      if (state.isLoading || state.isLoadingMore || !state.hasMore || storeId == null) {
        return;
      }

      set({ isLoadingMore: true });
      try {
        const nextPage = await repository.fetchProducts({
          storeId,
          searchQuery: state.currentSearchQuery,
          limit: PHARMACY_PRODUCTS_PAGE_SIZE,
          offset: state.products.length,
        });
        set({
          products: [...get().products, ...nextPage.filter(isPharmacyProductOverTheCounter)],
          hasMore: nextPage.length >= PHARMACY_PRODUCTS_PAGE_SIZE,
        });
      } catch {
        // Leave `hasMore` as-is so the trailing "load more" row stays
        // visible and a later scroll can retry -- mirrors the Dart source.
      } finally {
        set({ isLoadingMore: false });
      }
    },
  }));
}

let defaultStore: PharmacyCatalogStore | null = null;

/**
 * The app-wide catalog store (the Dart app's single `AppServices`-owned
 * `PharmacyController`). Built lazily so importing this module in a test
 * never constructs the Supabase-backed repository.
 */
export function defaultPharmacyCatalogStore(): PharmacyCatalogStore {
  defaultStore ??= createPharmacyCatalogStore();
  return defaultStore;
}
