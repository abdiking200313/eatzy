/**
 * Covers the row mapping and Supabase query shape of
 * `pharmacy-models.ts`/`pharmacy-repository.ts` (issue #394 / P7-06),
 * ported from `pharmacy_product.dart`/`pharmacy_store.dart`/
 * `pharmacy_repository.dart`. The Dart test suite exercises these only
 * indirectly (through `SeededPharmacyRepository`), so these cases pin the
 * Dart source's own validation rules directly.
 */
import { createFakeSupabaseClient, fakeSupabaseError, fakeSupabaseOk } from '@/test-utils/fake-supabase-client';

import { pharmacyProductFromRow, pharmacyStoreFromRow } from './pharmacy-models';
import {
  createInMemoryPharmacyRepository,
  createSupabasePharmacyCatalogRepository,
  fetchPharmacyStores,
  SEEDED_PHARMACY_STORE_ID,
  type PharmacySource,
} from './pharmacy-repository';

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

const productRow = {
  id: 'p1',
  store_id: 's1',
  name: ' Paracetamol ',
  description: null,
  unit_price: 275,
  stock_quantity: '24',
  sale_type: 'otc',
  image_url: '  ',
  pharmacy_categories: { id: 'c1', name: 'Pain relief' },
};

describe('pharmacyProductFromRow', () => {
  it('maps a row, trimming strings, parsing integer strings, and reading the embedded category', () => {
    expect(pharmacyProductFromRow(productRow)).toEqual({
      id: 'p1',
      storeId: 's1',
      name: 'Paracetamol',
      description: '',
      category: 'Pain relief',
      unitPrice: 275,
      stockQuantity: 24,
      saleType: 'overTheCounter',
      imageUrl: null,
    });
  });

  it('maps every sale type and rejects an unknown one', () => {
    expect(pharmacyProductFromRow({ ...productRow, sale_type: 'prescription_only' }).saleType).toBe('prescriptionOnly');
    expect(pharmacyProductFromRow({ ...productRow, sale_type: 'regulated' }).saleType).toBe('regulated');
    expect(() => pharmacyProductFromRow({ ...productRow, sale_type: 'herbal' })).toThrow('Unsupported pharmacy sale type: herbal');
  });

  it('rejects negative stock or price and non-integer values', () => {
    expect(() => pharmacyProductFromRow({ ...productRow, stock_quantity: -1 })).toThrow('cannot be negative');
    expect(() => pharmacyProductFromRow({ ...productRow, unit_price: -5 })).toThrow('cannot be negative');
    expect(() => pharmacyProductFromRow({ ...productRow, unit_price: 2.75 })).toThrow('Invalid pharmacy integer: unit_price');
  });

  it('falls back to a flat category_name column without an embed', () => {
    const { pharmacy_categories: _ignored, ...flat } = productRow;
    expect(pharmacyProductFromRow({ ...flat, category_name: 'Vitamins' }).category).toBe('Vitamins');
    expect(() => pharmacyProductFromRow(flat)).toThrow('Missing required pharmacy field: category_name');
  });
});

describe('pharmacyStoreFromRow', () => {
  it('requires id and name, defaults a missing address to empty and a blank photo to null', () => {
    expect(pharmacyStoreFromRow({ id: 'h', name: 'Hodan Pharmacy', address: null, image_url: '' })).toEqual({
      id: 'h',
      name: 'Hodan Pharmacy',
      address: '',
      imageUrl: null,
    });
    expect(() => pharmacyStoreFromRow({ id: 'h', name: ' ' })).toThrow('Missing required pharmacy store field: name');
  });
});

describe('fetchPharmacyStores', () => {
  it('queries active pharmacies ordered by name, adding an ilike filter only for a non-blank search', async () => {
    const client = createFakeSupabaseClient();
    client.queueTableResponse('pharmacy_stores', fakeSupabaseOk([{ id: 'h', name: 'Hodan Pharmacy', address: 'Hodan', image_url: null }]));
    client.queueTableResponse('pharmacy_stores', fakeSupabaseOk([]));
    const source = client as unknown as PharmacySource;

    expect(await fetchPharmacyStores('  ', source)).toEqual([{ id: 'h', name: 'Hodan Pharmacy', address: 'Hodan', imageUrl: null }]);
    await fetchPharmacyStores(' hodan ', source);

    expect(client.calls[0].steps).toEqual([
      { method: 'select', args: ['id, name, address, image_url'] },
      { method: 'eq', args: ['is_active', true] },
      { method: 'order', args: ['name'] },
    ]);
    expect(client.calls[1].steps).toContainEqual({ method: 'ilike', args: ['name', '%hodan%'] });
  });

  it('throws the Supabase error', async () => {
    const client = createFakeSupabaseClient();
    client.queueTableResponse('pharmacy_stores', fakeSupabaseError('boom'));
    await expect(fetchPharmacyStores(null, client as unknown as PharmacySource)).rejects.toMatchObject({ message: 'boom' });
  });
});

describe('createSupabasePharmacyCatalogRepository', () => {
  it('fetches one store\'s active OTC products as a ranged page and drops any non-OTC row', async () => {
    const client = createFakeSupabaseClient();
    client.queueTableResponse(
      'pharmacy_products',
      fakeSupabaseOk([productRow, { ...productRow, id: 'p2', sale_type: 'regulated' }]),
    );
    const repository = createSupabasePharmacyCatalogRepository(client as unknown as PharmacySource);

    const products = await repository.fetchProducts({ storeId: 's1', searchQuery: 'para', limit: 30, offset: 30 });

    expect(products.map((product) => product.id)).toEqual(['p1']);
    expect(client.calls[0]).toMatchObject({ kind: 'table', name: 'pharmacy_products' });
    expect(client.calls[0].steps).toEqual([
      {
        method: 'select',
        args: [
          'id, name, description, unit_price, stock_quantity, sale_type, image_url, store_id, pharmacy_categories!inner(id, name)',
        ],
      },
      { method: 'eq', args: ['is_active', true] },
      { method: 'eq', args: ['sale_type', 'otc'] },
      { method: 'eq', args: ['store_id', 's1'] },
      { method: 'eq', args: ['pharmacy_categories.is_active', true] },
      { method: 'ilike', args: ['name', '%para%'] },
      { method: 'order', args: ['name'] },
      { method: 'range', args: [30, 59] },
    ]);
  });

  it('fetches active categories ordered by name', async () => {
    const client = createFakeSupabaseClient();
    client.queueTableResponse('pharmacy_categories', fakeSupabaseOk([{ id: 'c1', name: 'Allergy' }]));
    const repository = createSupabasePharmacyCatalogRepository(client as unknown as PharmacySource);

    expect(await repository.fetchCategories()).toEqual([{ id: 'c1', name: 'Allergy' }]);
    expect(client.calls[0].steps).toEqual([
      { method: 'select', args: ['id, name'] },
      { method: 'eq', args: ['is_active', true] },
      { method: 'order', args: ['name'] },
    ]);
  });
});

describe('createInMemoryPharmacyRepository (SeededPharmacyRepository)', () => {
  it('scopes to one store, searches case-insensitively, and pages by offset/limit', async () => {
    const repository = createInMemoryPharmacyRepository();

    expect(await repository.fetchProducts({ storeId: 'elsewhere' })).toEqual([]);
    expect((await repository.fetchProducts({ storeId: SEEDED_PHARMACY_STORE_ID })).map((p) => p.id)).toHaveLength(5);
    expect((await repository.fetchProducts({ storeId: SEEDED_PHARMACY_STORE_ID, searchQuery: ' VITAMIN ' })).map((p) => p.name)).toEqual([
      'Vitamin C',
    ]);
    expect(
      (await repository.fetchProducts({ storeId: SEEDED_PHARMACY_STORE_ID, limit: 2, offset: 3 })).map((p) => p.id),
    ).toEqual(['wellness-vitamin-c', 'allergy-antihistamine']);
    expect(await repository.fetchProducts({ storeId: SEEDED_PHARMACY_STORE_ID, offset: 5 })).toEqual([]);
  });
});
