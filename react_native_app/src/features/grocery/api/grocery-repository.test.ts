/**
 * Ports `flutter_app/test/grocery_screens_test.dart`'s category-parsing
 * case ("products parse their embedded category...") for the Supabase row
 * mapping (issue #389 / P7-01) -- the cart-round-trip half of that Dart
 * test is already covered by `grocery-cart-store.test.ts` (issue #376);
 * this covers just `groceryProductFromRow`/`fetchGroceryStores`'s own
 * query + grouping behavior, which has no RN equivalent test yet.
 */
import { createFakeSupabaseClient, fakeSupabaseOk } from '@/test-utils/fake-supabase-client';

import { fetchGroceryStores, type GroceryStoreSource } from './grocery-repository';
import { groceryProductFromRow, groceryStoreTypeFromDb } from './grocery-store';

// `fetchGroceryStores`'s default parameter imports the real `supabase`
// client at module load time, even though every test here injects its own
// fake client -- same reasoning as `store-listing-repository.test.ts`.
jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

describe('groceryProductFromRow', () => {
  it('parses an embedded category and derives low/out-of-stock state from available_quantity vs. low_stock_threshold', () => {
    const inStock = groceryProductFromRow({
      id: 'p1',
      store_id: 's1',
      name: 'Bananas',
      description: null,
      unit_price: 150,
      pricing_unit: 'kilogram',
      quantity_step: 0.5,
      available_quantity: 10,
      low_stock_threshold: 3,
      icon: null,
      image_url: null,
      grocery_categories: { name: 'Fruits & vegetables', sort_order: 1 },
    });
    expect(inStock.categoryName).toBe('Fruits & vegetables');
    expect(inStock.categorySortOrder).toBe(1);
    expect(inStock.stockState).toBe('inStock');
    expect(inStock.icon).toBe('🛒');

    const outOfStock = groceryProductFromRow({
      id: 'p2',
      store_id: 's1',
      name: 'Tomatoes',
      description: null,
      unit_price: 220,
      pricing_unit: 'kilogram',
      quantity_step: 0.5,
      available_quantity: 0,
      low_stock_threshold: 3,
      icon: null,
      image_url: null,
      grocery_categories: null,
    });
    expect(outOfStock.stockState).toBe('outOfStock');
    expect(outOfStock.categoryName).toBeNull();
  });

  it('rejects a quantity_step that does not match its pricing unit', () => {
    expect(() =>
      groceryProductFromRow({
        id: 'p1',
        store_id: 's1',
        name: 'Rice',
        description: null,
        unit_price: 850,
        pricing_unit: 'each',
        quantity_step: 0.5,
        available_quantity: 10,
        low_stock_threshold: 3,
        icon: null,
        image_url: null,
        grocery_categories: null,
      }),
    ).toThrow(/quantity_step/);
  });
});

describe('groceryStoreTypeFromDb', () => {
  it('falls back to grocery for an unrecognized value, instead of hiding the store from every list', () => {
    expect(groceryStoreTypeFromDb('something-new')).toBe('grocery');
    expect(groceryStoreTypeFromDb('fresh_meat')).toBe('fresh_meat');
    expect(groceryStoreTypeFromDb('electronics')).toBe('electronics');
  });
});

describe('fetchGroceryStores', () => {
  it('groups products by store and fetches only active rows', async () => {
    const client = createFakeSupabaseClient();
    client.queueTableResponse(
      'grocery_stores',
      fakeSupabaseOk([
        { id: 'bakaal', name: 'Bakaal Fresh', area: 'Hodan', image_url: null, store_type: 'grocery' },
        { id: 'butcher', name: 'Hamar Meat', area: 'Hamar', image_url: null, store_type: 'fresh_meat' },
      ]),
    );
    client.queueTableResponse(
      'grocery_products',
      fakeSupabaseOk([
        {
          id: 'rice',
          store_id: 'bakaal',
          name: 'Rice',
          description: null,
          unit_price: 500,
          pricing_unit: 'each',
          quantity_step: 1,
          available_quantity: 10,
          low_stock_threshold: 2,
          icon: null,
          image_url: null,
          grocery_categories: null,
        },
        {
          id: 'goat',
          store_id: 'butcher',
          name: 'Goat',
          description: null,
          unit_price: 4000,
          pricing_unit: 'kilogram',
          quantity_step: 0.5,
          available_quantity: 5,
          low_stock_threshold: 1,
          icon: null,
          image_url: null,
          grocery_categories: null,
        },
      ]),
    );

    const stores = await fetchGroceryStores(client as unknown as GroceryStoreSource);

    expect(stores.map((s) => s.id)).toEqual(['bakaal', 'butcher']);
    expect(stores[0].products.map((p) => p.id)).toEqual(['rice']);
    expect(stores[1].storeType).toBe('fresh_meat');
    expect(stores[1].products.map((p) => p.id)).toEqual(['goat']);

    const storeCall = client.calls.find((call) => call.kind === 'table' && call.name === 'grocery_stores');
    expect(storeCall?.steps).toContainEqual({ method: 'eq', args: ['is_active', true] });
  });

  it('returns stores with no products as an empty array rather than throwing', async () => {
    const client = createFakeSupabaseClient();
    client.queueTableResponse(
      'grocery_stores',
      fakeSupabaseOk([{ id: 'empty-store', name: 'Empty Store', area: 'Nowhere', image_url: null, store_type: 'grocery' }]),
    );
    client.queueTableResponse('grocery_products', fakeSupabaseOk([]));

    const stores = await fetchGroceryStores(client as unknown as GroceryStoreSource);

    expect(stores).toHaveLength(1);
    expect(stores[0].products).toEqual([]);
  });
});
