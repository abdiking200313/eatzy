/**
 * RN coverage for `SupabaseMerchantCatalogRepository` (issue #410 / P9-05)
 * against `src/test-utils/fake-supabase-client.ts`. The Dart source has no
 * repository test of its own; these pin the per-vertical table/column
 * mapping (the live, cents-denominated `menu_items.price` /
 * `*.unit_price` columns), the grocery `quantity_step` invariant, the
 * pharmacy category requirement, store-scoped writes and error propagation.
 */
import { createFakeSupabaseClient, fakeSupabaseError, fakeSupabaseOk, type FakeSupabaseCall } from '@/test-utils/fake-supabase-client';

import type { MerchantCatalogItem } from './merchant-catalog-item';
import { MAX_ITEMS_PER_STORE, MerchantCatalogValidationError, SupabaseMerchantCatalogRepository, type MerchantCatalogSource } from './merchant-catalog-repository';

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

function setup() {
  const fake = createFakeSupabaseClient();
  const repo = new SupabaseMerchantCatalogRepository(fake as unknown as MerchantCatalogSource);
  return { fake, repo };
}

function stepArgs(call: FakeSupabaseCall, method: string): unknown[][] {
  return call.steps.filter((s) => s.method === method).map((s) => s.args);
}

function selectedColumns(call: FakeSupabaseCall): string[] {
  return String(stepArgs(call, 'select')[0][0])
    .split(',')
    .map((c) => c.trim());
}

const foodItem: MerchantCatalogItem = {
  id: 'item-1',
  storeId: 'r-1',
  vertical: 'food',
  name: '  Sambusa ',
  description: ' Fried ',
  priceCents: 250,
  isAvailable: true,
  imageUrl: '  ',
  pricingUnit: null,
  availableQuantity: null,
  categoryId: null,
  stockQuantity: null,
};

const groceryItem: MerchantCatalogItem = {
  ...foodItem,
  id: '',
  storeId: 'g-1',
  vertical: 'grocery',
  name: 'Bananas',
  pricingUnit: 'kilogram',
  availableQuantity: 12.5,
};

const pharmacyItem: MerchantCatalogItem = {
  ...foodItem,
  id: '',
  storeId: 'p-1',
  vertical: 'pharmacy',
  name: 'Paracetamol',
  categoryId: 'otc',
  stockQuantity: 30,
};

describe('SupabaseMerchantCatalogRepository', () => {
  it('fetchItems reads menu_items by restaurant_id with the cents price column, sorted and bounded', async () => {
    const { fake, repo } = setup();
    fake.queueTableResponse('menu_items', fakeSupabaseOk([{ id: 'm-1', name: 'Sambusa', description: null, price: 250, is_available: false, image_url: null }]));

    const items = await repo.fetchItems({ vertical: 'food', storeId: 'r-1' });

    const call = fake.calls[0];
    expect(call.name).toBe('menu_items');
    expect(selectedColumns(call)).toEqual(['id', 'name', 'description', 'price', 'is_available', 'image_url']);
    expect(stepArgs(call, 'eq')).toEqual([['restaurant_id', 'r-1']]);
    expect(stepArgs(call, 'order')).toEqual([['name']]);
    expect(stepArgs(call, 'limit')).toEqual([[MAX_ITEMS_PER_STORE]]);
    // Unavailable items are included -- no availability filter.
    expect(items).toEqual([
      expect.objectContaining({ id: 'm-1', storeId: 'r-1', vertical: 'food', priceCents: 250, isAvailable: false, pricingUnit: null }),
    ]);
  });

  it('fetchItems maps grocery and pharmacy-only columns', async () => {
    const { fake, repo } = setup();
    fake.queueTableResponse(
      'grocery_products',
      fakeSupabaseOk([{ id: 'g-p', name: 'Rice', unit_price: '199', is_active: true, pricing_unit: 'kilogram', available_quantity: '3.5' }]),
    );
    fake.queueTableResponse(
      'pharmacy_products',
      fakeSupabaseOk([{ id: 'p-p', name: 'ORS', unit_price: 120, is_active: true, category_id: 'otc', stock_quantity: 7 }]),
    );

    const [grocery] = await repo.fetchItems({ vertical: 'grocery', storeId: 'g-1' });
    const [pharmacy] = await repo.fetchItems({ vertical: 'pharmacy', storeId: 'p-1' });

    expect(selectedColumns(fake.calls[0])).toEqual(expect.arrayContaining(['unit_price', 'is_active', 'pricing_unit', 'available_quantity']));
    expect(stepArgs(fake.calls[0], 'eq')).toEqual([['store_id', 'g-1']]);
    expect(grocery).toMatchObject({ priceCents: 199, pricingUnit: 'kilogram', availableQuantity: 3.5, categoryId: null, stockQuantity: null });
    expect(selectedColumns(fake.calls[1])).toEqual(expect.arrayContaining(['category_id', 'stock_quantity']));
    expect(pharmacy).toMatchObject({ priceCents: 120, categoryId: 'otc', stockQuantity: 7, pricingUnit: null, availableQuantity: null });
  });

  it('createItem inserts a food item with a server-generated id and trimmed fields', async () => {
    const { fake, repo } = setup();
    fake.queueTableResponse('menu_items', fakeSupabaseOk({ id: 'uuid-1', name: 'Sambusa', price: 250, is_available: true }));

    const created = await repo.createItem({ ...foodItem, id: '' });

    const [payload] = stepArgs(fake.calls[0], 'insert')[0] as [Record<string, unknown>];
    expect(payload).toEqual({ name: 'Sambusa', description: 'Fried', price: 250, is_available: true, image_url: null, restaurant_id: 'r-1' });
    expect(created).toMatchObject({ id: 'uuid-1', storeId: 'r-1' });
  });

  it('createItem gives a grocery product a client id and the quantity_step its pricing unit requires', async () => {
    const { fake, repo } = setup();
    fake.queueTableResponse('grocery_products', fakeSupabaseOk({ id: 'bananas-x', name: 'Bananas' }));

    await repo.createItem(groceryItem);

    const [payload] = stepArgs(fake.calls[0], 'insert')[0] as [Record<string, unknown>];
    expect(payload).toMatchObject({
      store_id: 'g-1',
      unit_price: 250,
      is_active: true,
      pricing_unit: 'kilogram',
      quantity_step: 0.5,
      available_quantity: 12.5,
    });
    expect(typeof payload.id).toBe('string');
    expect(String(payload.id).length).toBeGreaterThan(0);
  });

  it('createItem writes a pharmacy product category and stock, and rejects a missing category', async () => {
    const { fake, repo } = setup();
    fake.queueTableResponse('pharmacy_products', fakeSupabaseOk({ id: 'para-x', name: 'Paracetamol' }));

    await repo.createItem(pharmacyItem);
    const [payload] = stepArgs(fake.calls[0], 'insert')[0] as [Record<string, unknown>];
    expect(payload).toMatchObject({ store_id: 'p-1', category_id: 'otc', stock_quantity: 30 });
    expect(payload).not.toHaveProperty('sale_type');

    await expect(repo.createItem({ ...pharmacyItem, categoryId: ' ' })).rejects.toBeInstanceOf(MerchantCatalogValidationError);
    expect(fake.calls).toHaveLength(1);
  });

  it('rejects a blank name without touching the database', async () => {
    const { fake, repo } = setup();

    await expect(repo.createItem({ ...foodItem, name: '  ' })).rejects.toThrow('An item name is required.');
    await expect(repo.updateItem({ ...foodItem, name: '' })).rejects.toThrow('An item name is required.');
    expect(fake.calls).toHaveLength(0);
  });

  it('updateItem, setAvailability and deleteItem are scoped to the item id and its store', async () => {
    const { fake, repo } = setup();
    fake.setDefaultTableResponse('menu_items', fakeSupabaseOk({ id: 'item-1', name: 'Sambusa', price: 300, is_available: false }));

    const updated = await repo.updateItem({ ...foodItem, priceCents: 300 });
    const toggled = await repo.setAvailability({ item: foodItem, isAvailable: false });
    await repo.deleteItem(foodItem);

    for (const call of fake.calls) {
      expect(stepArgs(call, 'eq')).toEqual([
        ['id', 'item-1'],
        ['restaurant_id', 'r-1'],
      ]);
    }
    expect((stepArgs(fake.calls[0], 'update')[0][0] as Record<string, unknown>).price).toBe(300);
    expect(stepArgs(fake.calls[1], 'update')[0][0]).toEqual({ is_available: false });
    expect(stepArgs(fake.calls[2], 'delete')).toHaveLength(1);
    expect(updated.priceCents).toBe(300);
    expect(toggled.isAvailable).toBe(false);
  });

  it('fetchPharmacyCategories reads active categories by name', async () => {
    const { fake, repo } = setup();
    fake.queueTableResponse('pharmacy_categories', fakeSupabaseOk([{ id: 'otc', name: 'OTC' }]));

    expect(await repo.fetchPharmacyCategories()).toEqual([{ id: 'otc', name: 'OTC' }]);
    expect(stepArgs(fake.calls[0], 'eq')).toEqual([['is_active', true]]);
    expect(stepArgs(fake.calls[0], 'order')).toEqual([['name']]);
  });

  it('propagates Supabase errors', async () => {
    const { fake, repo } = setup();
    fake.setDefaultTableResponse('menu_items', fakeSupabaseError('permission denied'));

    await expect(repo.fetchItems({ vertical: 'food', storeId: 'r-1' })).rejects.toBeTruthy();
    await expect(repo.updateItem(foodItem)).rejects.toBeTruthy();
    await expect(repo.deleteItem(foodItem)).rejects.toBeTruthy();
  });
});
