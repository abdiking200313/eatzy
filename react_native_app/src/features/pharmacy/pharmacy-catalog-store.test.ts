/**
 * Ports the catalog cases of `flutter_app/test/pharmacy_controller_test.dart`
 * (issue #394 / P7-06): the "catalog staleness and pull-to-refresh" group
 * and the "store-scoped catalog (issue #141)" group's loading cases. The
 * cross-pharmacy `storeConflict` cart case already lives in
 * `src/stores/pharmacy-cart-store.test.ts` (issue #376), as do the cart
 * cases; checkout cases belong to the checkout issue.
 */
import type { PharmacyProduct } from '@/stores/pharmacy-cart-store';

import {
  createInMemoryPharmacyRepository,
  PHARMACY_PRODUCTS_PAGE_SIZE,
  SEEDED_PHARMACY_STORE_ID,
  type FetchPharmacyProductsOptions,
  type PharmacyRepository,
} from './api/pharmacy-repository';
import { createPharmacyCatalogStore, PHARMACY_CATALOG_LOAD_ERROR, PHARMACY_CATALOG_STALE_AFTER_MS } from './pharmacy-catalog-store';

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

function product(id: string, storeId: string, name: string, overrides: Partial<PharmacyProduct> = {}): PharmacyProduct {
  return {
    id,
    storeId,
    name,
    description: '',
    category: 'General',
    unitPrice: 3,
    stockQuantity: 10,
    saleType: 'overTheCounter',
    ...overrides,
  };
}

/** Mirrors the Dart test's `_MultiStorePharmacyRepository`. */
const multiStoreProducts = [
  product('store-a-vitamin', 'store-a', 'Vitamin A (Store A)'),
  product('store-a-bandages', 'store-a', 'Bandages (Store A)'),
  product('store-b-cough-syrup', 'store-b', 'Cough Syrup (Store B)'),
];

/** Mirrors `_CountingPharmacyRepository`: wraps a repository and counts fetches. */
function counting(inner: PharmacyRepository = createInMemoryPharmacyRepository()) {
  const calls: FetchPharmacyProductsOptions[] = [];
  const repository: PharmacyRepository = {
    fetchProducts: (options) => {
      calls.push(options);
      return inner.fetchProducts(options);
    },
  };
  return { repository, calls };
}

describe('catalog staleness and pull-to-refresh', () => {
  it('loadProducts does not refetch an already-loaded, fresh catalog', async () => {
    const { repository, calls } = counting();
    const store = createPharmacyCatalogStore({ repository, now: () => Date.UTC(2026, 7, 27, 12) });

    await store.getState().loadProducts({ storeId: SEEDED_PHARMACY_STORE_ID });
    expect(calls).toHaveLength(1);

    await store.getState().loadProducts({ storeId: SEEDED_PHARMACY_STORE_ID });
    expect(calls).toHaveLength(1);
  });

  it('loadProducts refetches once the catalog goes stale', async () => {
    const { repository, calls } = counting();
    let now = Date.UTC(2026, 7, 27, 12);
    const store = createPharmacyCatalogStore({ repository, now: () => now });

    await store.getState().loadProducts({ storeId: SEEDED_PHARMACY_STORE_ID });
    expect(calls).toHaveLength(1);
    expect(store.getState().isStale()).toBe(false);

    now += PHARMACY_CATALOG_STALE_AFTER_MS;
    expect(store.getState().isStale()).toBe(true);

    await store.getState().loadProducts({ storeId: SEEDED_PHARMACY_STORE_ID });
    expect(calls).toHaveLength(2);
    expect(store.getState().isStale()).toBe(false);
  });

  it('loadProducts(forceRefresh: true) always refetches regardless of staleness', async () => {
    const { repository, calls } = counting();
    const store = createPharmacyCatalogStore({ repository, now: () => Date.UTC(2026, 7, 27, 12) });

    await store.getState().loadProducts({ storeId: SEEDED_PHARMACY_STORE_ID });
    await store.getState().loadProducts({ storeId: SEEDED_PHARMACY_STORE_ID, forceRefresh: true });
    expect(calls).toHaveLength(2);
  });
});

describe('store-scoped catalog (issue #141)', () => {
  it('loadProducts scopes the catalog to one pharmacy at a time', async () => {
    const { repository, calls } = counting(createInMemoryPharmacyRepository(multiStoreProducts));
    const store = createPharmacyCatalogStore({ repository });

    await store.getState().loadProducts({ storeId: 'store-a' });
    expect(store.getState().currentStoreId).toBe('store-a');
    expect(store.getState().products.every((p) => p.storeId === 'store-a')).toBe(true);
    expect(store.getState().products).toHaveLength(2);

    // Switching pharmacy always refetches (even while fresh) and replaces
    // the list rather than appending to it.
    await store.getState().loadProducts({ storeId: 'store-b' });
    expect(store.getState().currentStoreId).toBe('store-b');
    expect(store.getState().products.map((p) => p.storeId)).toEqual(['store-b']);
    expect(calls).toHaveLength(2);
  });

  it('loadProducts narrows results with a search query', async () => {
    const store = createPharmacyCatalogStore({ repository: createInMemoryPharmacyRepository(multiStoreProducts) });

    await store.getState().loadProducts({ storeId: 'store-a', searchQuery: 'Vitamin' });

    expect(store.getState().products.map((p) => p.name)).toEqual(['Vitamin A (Store A)']);
  });

  it('a changed search query refetches even while fresh, and a blank query normalizes to none', async () => {
    const { repository, calls } = counting(createInMemoryPharmacyRepository(multiStoreProducts));
    const store = createPharmacyCatalogStore({ repository });

    await store.getState().loadProducts({ storeId: 'store-a' });
    await store.getState().loadProducts({ storeId: 'store-a', searchQuery: '   ' });
    expect(calls).toHaveLength(1);

    await store.getState().loadProducts({ storeId: 'store-a', searchQuery: ' band ' });
    expect(calls).toHaveLength(2);
    expect(calls[1].searchQuery).toBe('band');
  });
});

describe('loading, errors, and paging', () => {
  it('filters out non-OTC products the repository returns', async () => {
    const store = createPharmacyCatalogStore({
      repository: createInMemoryPharmacyRepository([
        product('otc', 'store-a', 'OTC item'),
        product('rx', 'store-a', 'Rx item', { saleType: 'prescriptionOnly' }),
      ]),
    });

    await store.getState().loadProducts({ storeId: 'store-a' });

    expect(store.getState().products.map((p) => p.id)).toEqual(['otc']);
  });

  it('records a load error, keeps previously loaded products, and clears the error on the next load', async () => {
    let fail = false;
    const inner = createInMemoryPharmacyRepository(multiStoreProducts);
    const store = createPharmacyCatalogStore({
      repository: {
        fetchProducts: (options) => (fail ? Promise.reject(new Error('offline')) : inner.fetchProducts(options)),
      },
    });

    await store.getState().loadProducts({ storeId: 'store-a' });
    fail = true;
    await store.getState().loadProducts({ storeId: 'store-a', forceRefresh: true });
    expect(store.getState().loadError).toBe(PHARMACY_CATALOG_LOAD_ERROR);
    expect(store.getState().isLoading).toBe(false);
    expect(store.getState().products).toHaveLength(2);

    fail = false;
    await store.getState().loadProducts({ storeId: 'store-a', forceRefresh: true });
    expect(store.getState().loadError).toBeNull();
  });

  it('loadMore appends the next page until a short page ends the catalog, and no-ops before any load', async () => {
    const many = Array.from({ length: PHARMACY_PRODUCTS_PAGE_SIZE + 5 }, (_, i) =>
      product(`p-${String(i).padStart(2, '0')}`, 'store-a', `Item ${String(i).padStart(2, '0')}`),
    );
    const { repository, calls } = counting(createInMemoryPharmacyRepository(many));
    const store = createPharmacyCatalogStore({ repository });

    await store.getState().loadMore();
    expect(calls).toHaveLength(0);

    await store.getState().loadProducts({ storeId: 'store-a' });
    expect(store.getState().products).toHaveLength(PHARMACY_PRODUCTS_PAGE_SIZE);
    expect(store.getState().hasMore).toBe(true);

    await store.getState().loadMore();
    expect(calls[1]).toMatchObject({ storeId: 'store-a', offset: PHARMACY_PRODUCTS_PAGE_SIZE });
    expect(store.getState().products).toHaveLength(PHARMACY_PRODUCTS_PAGE_SIZE + 5);
    expect(store.getState().hasMore).toBe(false);
    expect(store.getState().isLoadingMore).toBe(false);

    await store.getState().loadMore();
    expect(calls).toHaveLength(2);
  });

  it('a failed loadMore leaves hasMore set so a later scroll can retry', async () => {
    const many = Array.from({ length: PHARMACY_PRODUCTS_PAGE_SIZE }, (_, i) => product(`p-${i}`, 'store-a', `Item ${i}`));
    const inner = createInMemoryPharmacyRepository(many);
    let fail = false;
    const store = createPharmacyCatalogStore({
      repository: {
        fetchProducts: (options) => (fail ? Promise.reject(new Error('offline')) : inner.fetchProducts(options)),
      },
    });

    await store.getState().loadProducts({ storeId: 'store-a' });
    fail = true;
    await store.getState().loadMore();

    expect(store.getState().hasMore).toBe(true);
    expect(store.getState().isLoadingMore).toBe(false);
    expect(store.getState().products).toHaveLength(PHARMACY_PRODUCTS_PAGE_SIZE);
  });
});
