/**
 * Ports the cart-scoped cases of `flutter_app/test/pharmacy_controller_test.dart`
 * (issue #376) against `pharmacy-cart-store.ts`'s cart slice directly --
 * catalog loading (`loadProducts`/`loadMore`) and checkout
 * (`placeDemoOrder`) are out of scope here (belong to #379), so this skips
 * that Dart file's catalog-staleness and checkout groups. Explicitly covers
 * the decrement-removes-at-1 behavior this store's own doc comment calls
 * out as a deliberate difference from the food cart's decrement (which
 * no-ops at quantity 1 instead -- see `food-cart-store.test.ts`'s
 * "decrement never drops quantity below 1" case).
 *
 * Mocks `@/platform/supabase/client` for the same reason
 * `food-cart-store.test.ts` does -- see that file's top comment.
 */
import { queryClient } from '@/platform/query/query-client';
import { MemoryCartStorage } from '@/test-utils/memory-cart-storage';

import {
  computePharmacyCartTotals,
  createPharmacyCartStore,
  isPharmacyProductAvailable,
  isPharmacyProductLowStock,
  isPharmacyProductOverTheCounter,
  pharmacyCartItemFromJson,
  pharmacyCartItemToJson,
  pharmacyProductFromJson,
  pharmacyProductToJson,
  selectPharmacyCartItemCount,
  selectPharmacyCartSubtotal,
  type PharmacyCartItem,
  type PharmacyProduct,
} from './pharmacy-cart-store';
import { SessionResetRegistry } from './session-reset-registry';

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

const paracetamol: PharmacyProduct = {
  id: 'paracetamol',
  storeId: 'store-1',
  name: 'Paracetamol',
  description: 'Pain relief tablets.',
  category: 'Pain relief',
  unitPrice: 275,
  stockQuantity: 24,
  saleType: 'overTheCounter',
  imageUrl: null,
};

const unavailableProduct: PharmacyProduct = { ...paracetamol, id: 'out-of-stock', stockQuantity: 0 };
const prescriptionProduct: PharmacyProduct = { ...paracetamol, id: 'prescription-only', saleType: 'prescriptionOnly' };
const storeAItem: PharmacyProduct = { ...paracetamol, id: 'a-1', storeId: 'store-a' };
const storeBItem: PharmacyProduct = { ...paracetamol, id: 'b-1', storeId: 'store-b' };

const standardPharmacyPricing = { serviceId: 'pharmacy' as const, deliveryFeeCents: 250, taxRate: 0 };

function build(storage: MemoryCartStorage<PharmacyCartItem> = new MemoryCartStorage<PharmacyCartItem>()) {
  return createPharmacyCartStore({ storage, registry: new SessionResetRegistry() });
}

// See `food-cart-store.test.ts`'s identical `afterAll` for why this is here.
afterAll(() => {
  queryClient.clear();
});

describe('pharmacy cart store (issue #376)', () => {
  it('adds, adjusts, removes, and calculates totals', async () => {
    const { store } = build();
    await store.getState().loadForOwner('user-1');

    expect(store.getState().addProduct(paracetamol)).toBe('added');
    expect(store.getState().addProduct(paracetamol)).toBe('quantityIncreased');

    const items = store.getState().items;
    expect(items).toHaveLength(1);
    expect(selectPharmacyCartItemCount(items)).toBe(2);
    expect(selectPharmacyCartSubtotal(items)).toBe(550);

    const totals = computePharmacyCartTotals(items, standardPharmacyPricing);
    expect(totals.deliveryFee).toBe(250);
    expect(totals.total).toBe(800);

    store.getState().decrement(paracetamol.id);
    expect(store.getState().items[0].quantity).toBe(1);

    store.getState().removeProduct(paracetamol.id);
    expect(store.getState().items).toEqual([]);
    expect(computePharmacyCartTotals(store.getState().items, standardPharmacyPricing).total).toBe(0);
  });

  it('decrement removes the item entirely once its quantity would drop to zero (unlike the food cart)', async () => {
    const { store } = build();
    await store.getState().loadForOwner('user-1');
    store.getState().addProduct(paracetamol);
    expect(store.getState().items[0].quantity).toBe(1);

    store.getState().decrement(paracetamol.id);

    expect(store.getState().items).toEqual([]);
  });

  it('adds several units at once, all or nothing', async () => {
    const { store } = build();
    await store.getState().loadForOwner('user-1'); // 24 in stock

    expect(store.getState().addProduct(paracetamol, { quantity: 20 })).toBe('added');
    expect(store.getState().addProduct(paracetamol, { quantity: 5 })).toBe('maximumStockReached');
    expect(store.getState().items[0].quantity).toBe(20);

    expect(store.getState().addProduct(paracetamol, { quantity: 4 })).toBe('quantityIncreased');
    expect(store.getState().items[0].quantity).toBe(24);
  });

  it('an unavailable (out of stock) OTC product cannot be added', async () => {
    const { store } = build();
    await store.getState().loadForOwner('user-1');

    expect(store.getState().addProduct(unavailableProduct)).toBe('unavailable');
    expect(store.getState().items).toEqual([]);
  });

  it('a non-OTC (prescription/regulated) product is rejected', async () => {
    const { store } = build();
    await store.getState().loadForOwner('user-1');

    expect(store.getState().addProduct(prescriptionProduct)).toBe('notOverTheCounter');
    expect(store.getState().items).toEqual([]);
  });

  it('increment is a no-op once quantity reaches stockQuantity', async () => {
    const { store } = build();
    await store.getState().loadForOwner('user-1');
    store.getState().addProduct(paracetamol, { quantity: 24 });

    store.getState().increment(paracetamol.id);

    expect(store.getState().items[0].quantity).toBe(24);
  });

  it('increment/decrement/removeProduct on an item not in the cart are no-ops', async () => {
    const { store } = build();
    await store.getState().loadForOwner('user-1');

    store.getState().increment('missing');
    store.getState().decrement('missing');
    store.getState().removeProduct('missing');

    expect(store.getState().items).toEqual([]);
  });

  describe('store-switching/replace', () => {
    it('adding a product from a different pharmacy is rejected without replaceStoreCart', async () => {
      const { store } = build();
      await store.getState().loadForOwner('user-1');

      expect(store.getState().addProduct(storeAItem)).toBe('added');
      expect(store.getState().addProduct(storeBItem)).toBe('storeConflict');
      expect(store.getState().items).toHaveLength(1);
      expect(store.getState().items[0].product.id).toBe('a-1');

      expect(store.getState().addProduct(storeBItem, { replaceStoreCart: true })).toBe('added');
      expect(store.getState().items).toHaveLength(1);
      expect(store.getState().items[0].product.id).toBe('b-1');
    });
  });

  describe('persistence and account switching', () => {
    it('pharmacy cart survives a simulated app reload', async () => {
      const storage = new MemoryCartStorage<PharmacyCartItem>();
      const original = build(storage);
      await original.store.getState().loadForOwner('user-1');
      original.store.getState().addProduct(paracetamol);
      original.store.getState().increment(paracetamol.id);
      await original.pendingWrite();

      const restored = build(storage);
      await restored.store.getState().loadForOwner('user-1');

      expect(restored.store.getState().items).toHaveLength(1);
      expect(restored.store.getState().items[0].product.id).toBe(paracetamol.id);
      expect(restored.store.getState().items[0].quantity).toBe(2);
    });

    it('switching accounts clears and reloads the pharmacy cart', async () => {
      const storage = new MemoryCartStorage<PharmacyCartItem>();
      const handle = build(storage);
      await handle.store.getState().loadForOwner('user-1');
      handle.store.getState().addProduct(paracetamol);
      await handle.pendingWrite();

      await handle.store.getState().loadForOwner('user-2');
      expect(handle.store.getState().items).toEqual([]);

      const otherProduct: PharmacyProduct = { ...paracetamol, id: 'other' };
      handle.store.getState().addProduct(otherProduct);
      await handle.pendingWrite();
      await handle.store.getState().loadForOwner('user-1');
      expect(handle.store.getState().items[0].product.id).toBe(paracetamol.id);

      await handle.store.getState().loadForOwner('user-2');
      expect(handle.store.getState().items[0].product.id).toBe('other');
    });

    it('clearCart is a no-op on an already-empty cart, and otherwise persists', async () => {
      const storage = new MemoryCartStorage<PharmacyCartItem>();
      const handle = build(storage);
      await handle.store.getState().loadForOwner('user-1');

      handle.store.getState().clearCart();
      await handle.pendingWrite();
      expect(await storage.read('user-1')).toEqual([]);

      handle.store.getState().addProduct(paracetamol);
      await handle.pendingWrite();
      expect(await storage.read('user-1')).toHaveLength(1);

      handle.store.getState().clearCart();
      await handle.pendingWrite();
      expect(await storage.read('user-1')).toEqual([]);
    });
  });

  describe('models', () => {
    it('isPharmacyProductOverTheCounter/isAvailable/isLowStock', () => {
      expect(isPharmacyProductOverTheCounter(paracetamol)).toBe(true);
      expect(isPharmacyProductOverTheCounter(prescriptionProduct)).toBe(false);

      expect(isPharmacyProductAvailable(paracetamol)).toBe(true);
      expect(isPharmacyProductAvailable(unavailableProduct)).toBe(false);

      expect(isPharmacyProductLowStock({ ...paracetamol, stockQuantity: 5 })).toBe(true);
      expect(isPharmacyProductLowStock({ ...paracetamol, stockQuantity: 0 })).toBe(false);
      expect(isPharmacyProductLowStock(paracetamol)).toBe(false); // 24 in stock
    });

    it('PharmacyProduct.toJson/fromJson round-trips', () => {
      const withPhoto: PharmacyProduct = { ...paracetamol, imageUrl: 'https://cdn.test/paracetamol.jpg' };
      expect(pharmacyProductFromJson(pharmacyProductToJson(withPhoto))).toEqual(withPhoto);
    });

    it('PharmacyProduct.fromJson rejects an unsupported sale type', () => {
      expect(() => pharmacyProductFromJson({ ...pharmacyProductToJson(paracetamol), sale_type: 'subscription' })).toThrow();
    });

    it('PharmacyCartItem.toJson/fromJson round-trips, and rejects a quantity below 1', () => {
      const item: PharmacyCartItem = { product: paracetamol, quantity: 3 };
      expect(pharmacyCartItemFromJson(pharmacyCartItemToJson(item))).toEqual(item);
      expect(() => pharmacyCartItemFromJson({ ...pharmacyCartItemToJson(item), quantity: 0 })).toThrow();
    });
  });
});
