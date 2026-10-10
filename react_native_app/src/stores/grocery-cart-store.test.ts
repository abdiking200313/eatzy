/**
 * Cart-only coverage for `grocery-cart-store.ts` (issue #376). There is no
 * single Flutter test file scoped to just `GroceryCart`'s quantity-step/
 * store-switching rules (`grocery_controller_test.dart` exercises them
 * through `GroceryController`, which also owns catalog loading and checkout
 * -- out of scope here, belonging to #379) -- this ports that file's
 * cart-scoped cases (quantity-step totals, unavailable/stock-limited
 * products, all-or-nothing multi-step adds, reload/account-switch
 * persistence) against this store directly, adapted to its "all three
 * `GroceryStoreType`s share one engine" shape via `createGroceryCartStore`,
 * plus store-switching/replace coverage (ported from
 * `pharmacy_controller_test.dart`'s equivalent case, since `GroceryCart` has
 * the identical `replaceStoreCart` contract) and the `setQuantity`/
 * `clearInMemory`/`clearAndPersist` pieces specific to this store's shape.
 *
 * Mocks `@/platform/supabase/client` for the same reason
 * `food-cart-store.test.ts` does -- see that file's top comment.
 */
import { queryClient } from '@/platform/query/query-client';
import { MemoryCartStorage } from '@/test-utils/memory-cart-storage';

import {
  computeGroceryCartTotals,
  createGroceryCartStore,
  groceryCartLineFromJson,
  groceryCartLineToJson,
  groceryProductFromJson,
  groceryProductToJson,
  groceryQuantityLabel,
  groceryQuantityStep,
  isGroceryProductAvailable,
  selectGroceryCartSubtotal,
  type GroceryCartLine,
  type GroceryProduct,
} from './grocery-cart-store';
import { SessionResetRegistry } from './session-reset-registry';

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

// `imageUrl`/`categoryName`/`categorySortOrder` are set explicitly (rather
// than left absent) on every fixture below so a round trip through
// `groceryProductToJson`/`groceryProductFromJson` -- which always fills
// these in with `null`/`0` -- compares equal via `toEqual` against the
// original fixture.
const rice: GroceryProduct = {
  id: 'rice',
  storeId: 'store-1',
  name: 'Rice',
  description: '',
  unitPrice: 500,
  pricingUnit: 'each',
  stockState: 'inStock',
  availableQuantity: 10,
  icon: '🍚',
  imageUrl: null,
  categoryName: null,
  categorySortOrder: 0,
};

const bananas: GroceryProduct = {
  id: 'bananas',
  storeId: 'store-1',
  name: 'Bananas',
  description: '',
  unitPrice: 400, // per kilogram
  pricingUnit: 'kilogram',
  stockState: 'inStock',
  availableQuantity: 12,
  icon: '🍌',
  imageUrl: null,
  categoryName: null,
  categorySortOrder: 0,
};

const tomatoes: GroceryProduct = {
  id: 'tomatoes',
  storeId: 'store-1',
  name: 'Tomatoes',
  description: '',
  unitPrice: 200,
  pricingUnit: 'each',
  stockState: 'outOfStock',
  availableQuantity: 5,
  icon: '🍅',
  imageUrl: null,
  categoryName: null,
  categorySortOrder: 0,
};

const milk: GroceryProduct = {
  id: 'milk',
  storeId: 'store-1',
  name: 'Milk',
  description: '',
  unitPrice: 300,
  pricingUnit: 'each',
  stockState: 'inStock',
  availableQuantity: 3,
  icon: '🥛',
  imageUrl: null,
  categoryName: null,
  categorySortOrder: 0,
};

const storeAItem: GroceryProduct = { ...rice, id: 'a-1', storeId: 'store-a', name: 'Store A item' };
const storeBItem: GroceryProduct = { ...rice, id: 'b-1', storeId: 'store-b', name: 'Store B item' };

const standardGroceryPricing = { serviceId: 'grocery' as const, deliveryFeeCents: 250, taxRate: 0 };

function build(storage: MemoryCartStorage<GroceryCartLine> = new MemoryCartStorage<GroceryCartLine>()) {
  return createGroceryCartStore('grocery', { storage, registry: new SessionResetRegistry() });
}

// See `food-cart-store.test.ts`'s identical `afterAll` for why this is here.
afterAll(() => {
  queryClient.clear();
});

describe('grocery cart store (issue #376)', () => {
  it('calculates unit and weighted product totals', async () => {
    const { store } = build();
    await store.getState().loadForOwner('user-1');

    expect(store.getState().addProduct(rice)).toBe('added');
    expect(store.getState().addProduct(bananas)).toBe('added');
    expect(store.getState().setQuantity(bananas.id, 1.5)).toBe(true);

    const lines = store.getState().lines;
    expect(selectGroceryCartSubtotal(lines)).toBe(1100); // 500 + round(400 * 1.5)

    const totals = computeGroceryCartTotals(lines, standardGroceryPricing);
    expect(totals.deliveryFee).toBe(250);
    expect(totals.total).toBe(1350);
  });

  it('does not add unavailable products, and rejects a quantity change that would exceed available stock', async () => {
    const { store } = build();
    await store.getState().loadForOwner('user-1');

    expect(store.getState().addProduct(tomatoes)).toBe('unavailable');
    expect(store.getState().lines).toEqual([]);

    expect(store.getState().addProduct(milk)).toBe('added');
    expect(store.getState().setQuantity(milk.id, 3)).toBe(true);
    expect(store.getState().increment(milk.id)).toBe(false); // 4 > availableQuantity (3)
    expect(store.getState().lines[0].quantity).toBe(3);
  });

  it('adds several quantity steps at once, all or nothing', async () => {
    const { store } = build();
    await store.getState().loadForOwner('user-1');

    expect(store.getState().addProduct(bananas, { steps: 4 })).toBe('added');
    expect(store.getState().lines[0].quantity).toBe(2);

    expect(store.getState().addProduct(bananas, { steps: 21 })).toBe('stockLimitReached');
    expect(store.getState().lines[0].quantity).toBe(2);
  });

  it('decrementing to zero removes the line entirely', async () => {
    const { store } = build();
    await store.getState().loadForOwner('user-1');
    store.getState().addProduct(milk);

    expect(store.getState().decrement(milk.id)).toBe(true);

    expect(store.getState().lines).toEqual([]);
  });

  it('setQuantity rejects a value that is not a whole number of steps, or exceeds available stock', async () => {
    const { store } = build();
    await store.getState().loadForOwner('user-1');
    store.getState().addProduct(milk);

    expect(store.getState().setQuantity(milk.id, 1.3)).toBe(false);
    expect(store.getState().setQuantity(milk.id, 10)).toBe(false);
    expect(store.getState().lines[0].quantity).toBe(1);
  });

  it('remove reports whether anything was actually removed', async () => {
    const { store } = build();
    await store.getState().loadForOwner('user-1');
    store.getState().addProduct(rice);

    expect(store.getState().remove('does-not-exist')).toBe(false);
    expect(store.getState().remove(rice.id)).toBe(true);
    expect(store.getState().lines).toEqual([]);
  });

  describe('store-switching/replace', () => {
    it('adding a product from a different store is rejected without replaceStoreCart', async () => {
      const { store } = build();
      await store.getState().loadForOwner('user-1');

      expect(store.getState().addProduct(storeAItem)).toBe('added');
      expect(store.getState().addProduct(storeBItem)).toBe('storeConflict');
      expect(store.getState().lines).toHaveLength(1);
      expect(store.getState().lines[0].product.id).toBe('a-1');

      expect(store.getState().addProduct(storeBItem, { replaceStoreCart: true })).toBe('added');
      expect(store.getState().lines).toHaveLength(1);
      expect(store.getState().lines[0].product.id).toBe('b-1');
    });
  });

  describe('persistence and account switching', () => {
    it('grocery cart survives a simulated app reload', async () => {
      const storage = new MemoryCartStorage<GroceryCartLine>();
      const original = build(storage);
      await original.store.getState().loadForOwner('user-1');
      original.store.getState().addProduct(rice);
      original.store.getState().setQuantity(rice.id, 2);
      await original.pendingWrite();

      const restored = build(storage);
      await restored.store.getState().loadForOwner('user-1');

      expect(restored.store.getState().lines).toHaveLength(1);
      expect(restored.store.getState().lines[0].product.id).toBe(rice.id);
      expect(restored.store.getState().lines[0].quantity).toBe(2);
    });

    it('switching accounts clears and reloads the grocery cart', async () => {
      const storage = new MemoryCartStorage<GroceryCartLine>();
      const handle = build(storage);
      await handle.store.getState().loadForOwner('user-1');
      handle.store.getState().addProduct(rice);
      await handle.pendingWrite();

      await handle.store.getState().loadForOwner('user-2');
      expect(handle.store.getState().lines).toEqual([]);

      handle.store.getState().addProduct(bananas);
      await handle.pendingWrite();
      await handle.store.getState().loadForOwner('user-1');
      expect(handle.store.getState().lines[0].product.id).toBe('rice');

      await handle.store.getState().loadForOwner('user-2');
      expect(handle.store.getState().lines[0].product.id).toBe('bananas');
    });

    it('clearInMemory resets in-memory state only; clearAndPersist also clears storage', async () => {
      const storage = new MemoryCartStorage<GroceryCartLine>();
      const handle = build(storage);
      await handle.store.getState().loadForOwner('user-1');
      handle.store.getState().addProduct(rice);
      await handle.pendingWrite();
      expect(await storage.read('user-1')).toHaveLength(1);

      handle.store.getState().clearInMemory();
      expect(handle.store.getState().lines).toEqual([]);
      // Not persisted -- storage still has the previously-written line.
      expect(await storage.read('user-1')).toHaveLength(1);

      await handle.store.getState().clearAndPersist();
      expect(await storage.read('user-1')).toEqual([]);
    });
  });

  describe('models', () => {
    it('groceryQuantityStep is 1 for "each" and 0.5 kg for "kilogram"', () => {
      expect(groceryQuantityStep('each')).toBe(1);
      expect(groceryQuantityStep('kilogram')).toBe(0.5);
    });

    it('isGroceryProductAvailable requires in-stock and enough available quantity for one step', () => {
      expect(isGroceryProductAvailable(rice)).toBe(true);
      expect(isGroceryProductAvailable(tomatoes)).toBe(false);
      expect(isGroceryProductAvailable({ ...bananas, availableQuantity: 0.25 })).toBe(false);
    });

    it('quantityLabel formats weighed products in kg and unit products as a whole count', () => {
      expect(groceryQuantityLabel({ product: bananas, quantity: 1.5 })).toBe('1.5 kg');
      expect(groceryQuantityLabel({ product: rice, quantity: 2 })).toBe('2');
    });

    it('GroceryProduct.toJson/fromJson round-trips, including a photo URL', () => {
      const withPhoto: GroceryProduct = { ...bananas, imageUrl: 'https://cdn.test/bananas.jpg' };
      expect(groceryProductFromJson(groceryProductToJson(withPhoto))).toEqual(withPhoto);
    });

    it('GroceryProduct.fromJson rejects an unsupported pricing unit or stock state', () => {
      expect(() => groceryProductFromJson({ ...groceryProductToJson(rice), pricing_unit: 'litre' })).toThrow();
      expect(() => groceryProductFromJson({ ...groceryProductToJson(rice), stock_state: 'discontinued' })).toThrow();
    });

    it('GroceryCartLine.toJson/fromJson round-trips, and rejects a non-positive quantity', () => {
      const line: GroceryCartLine = { product: bananas, quantity: 1.5 };
      expect(groceryCartLineFromJson(groceryCartLineToJson(line))).toEqual(line);
      expect(() => groceryCartLineFromJson({ ...groceryCartLineToJson(line), quantity: 0 })).toThrow();
    });
  });
});
