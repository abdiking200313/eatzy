/**
 * Ports `flutter_app/test/cart_controller_test.dart` (issue #376) against
 * this file's `createFoodCartStore`/`CartItem`/totals ports. Each case
 * builds its own isolated store (`createFoodCartStore` with a fresh
 * `MemoryCartStorage`/`SessionResetRegistry`), never the app-wide
 * `useFoodCartStore` singleton, so tests cannot see each other's state --
 * same posture as `merchant-session-gate.test.ts`.
 *
 * `food-cart-store.ts` imports `ServicePricingRepository`, which imports the
 * real `@/platform/supabase/client` -- mocked out here the same way
 * `merchant-session-gate.test.ts`/`store-listing-repository.test.ts` do,
 * since `loadForOwner`'s background pricing warm-up
 * (`void ServicePricingRepository.load(...)`) would otherwise reach a real
 * network client. Totals that depend on pricing are instead asserted via
 * `computeFoodCartTotals(items, pricing)` with an explicit `ServicePricing`
 * value, mirroring the Dart test's injected `FakeServicePricingRepository`.
 */
import { queryClient } from '@/platform/query/query-client';
import { MemoryCartStorage } from '@/test-utils/memory-cart-storage';

import {
  FOOD_CART_MAXIMUM_QUANTITY,
  cartItemFromJson,
  cartItemToJson,
  computeFoodCartTotals,
  createFoodCartStore,
  selectFoodCartItemCount,
  selectFoodCartSubtotal,
  type CartItem,
} from './food-cart-store';
import { SessionResetRegistry } from './session-reset-registry';

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

const burger: CartItem = {
  menuItemId: 'burger-1',
  restaurantId: 'restaurant-1',
  restaurantName: 'Test Kitchen',
  name: 'Classic Burger',
  unitPrice: 1000,
  imageUrl: '',
  quantity: 1,
};

const pizza: CartItem = {
  menuItemId: 'pizza-1',
  restaurantId: 'restaurant-2',
  restaurantName: 'Pizza Place',
  name: 'Margherita',
  unitPrice: 1200,
  imageUrl: '',
  quantity: 1,
};

/** 499 cents delivery / 10% tax -- the standard default `fake_service_pricing_repository.dart`'s `.food()` factory also uses. */
const standardFoodPricing = { serviceId: 'food' as const, deliveryFeeCents: 499, taxRate: 0.1 };

function build(storage: MemoryCartStorage<CartItem> = new MemoryCartStorage<CartItem>()) {
  return createFoodCartStore({ storage, registry: new SessionResetRegistry() });
}

// `loadForOwner` fires a background `ServicePricingRepository.load('food')`
// against the real, app-wide `queryClient` singleton (mocked Supabase
// client above makes every such call fail, but TanStack Query still leaves
// a cache entry with a pending `gcTime` cleanup timer behind) -- clear it
// once this suite finishes, the same way `service-pricing-repository.test.tsx`
// does, so Jest doesn't report a leaked timer.
afterAll(() => {
  queryClient.clear();
});

describe('food cart store (issue #376)', () => {
  it('adding the same menu item increases its quantity and totals', async () => {
    const { store } = build();
    await store.getState().loadForOwner('user-1');

    expect(await store.getState().addItem(burger)).toBe('added');
    expect(await store.getState().addItem(burger)).toBe('quantityIncreased');

    const items = store.getState().items;
    expect(items).toHaveLength(1);
    expect(items[0].quantity).toBe(2);
    expect(selectFoodCartItemCount(items)).toBe(2);
    expect(selectFoodCartSubtotal(items)).toBe(2000);

    const totals = computeFoodCartTotals(items, standardFoodPricing);
    expect(totals.tax).toBe(200);
    expect(totals.deliveryFee).toBe(499);
    expect(totals.total).toBe(2699);
  });

  it('changing the pricing changes the displayed fee/tax estimate immediately (issue #279)', () => {
    const items: CartItem[] = [{ ...burger, quantity: 1 }];

    let totals = computeFoodCartTotals(items, { serviceId: 'food', deliveryFeeCents: 999, taxRate: 0.05 });
    expect(totals.deliveryFee).toBe(999);
    expect(totals.tax).toBe(50);
    expect(totals.total).toBe(1000 + 50 + 999);

    // A changed `service_pricing` row -- simulated by passing a different
    // `ServicePricing` value, the same way a fresh load would pick up a
    // changed table row -- is reflected immediately with no stale hardcoded
    // constant left to diverge from it.
    totals = computeFoodCartTotals(items, { serviceId: 'food', deliveryFeeCents: 150, taxRate: 0.2 });
    expect(totals.deliveryFee).toBe(150);
    expect(totals.tax).toBe(200);
    expect(totals.total).toBe(1000 + 200 + 150);
  });

  it('reports fees/tax/total as unknown (null) until pricing has ever loaded, but an empty cart is always known to cost nothing (issue #279)', async () => {
    const { store } = build();
    await store.getState().loadForOwner('user-1');
    await store.getState().addItem(burger);

    let totals = computeFoodCartTotals(store.getState().items, undefined);
    expect(totals.deliveryFee).toBeNull();
    expect(totals.tax).toBeNull();
    expect(totals.total).toBeNull();

    await store.getState().remove(burger.menuItemId);
    totals = computeFoodCartTotals(store.getState().items, undefined);
    expect(totals.deliveryFee).toBe(0);
    expect(totals.tax).toBe(0);
    expect(totals.total).toBe(0);
  });

  it('cart restores from storage for the same signed-in account, and is isolated per owner', async () => {
    const storage = new MemoryCartStorage<CartItem>();
    const original = build(storage);
    await original.store.getState().loadForOwner('user-1');
    await original.store.getState().addItem(burger);
    await original.store.getState().increment(burger.menuItemId);

    const restored = build(storage);
    await restored.store.getState().loadForOwner('user-1');

    const items = restored.store.getState().items;
    expect(items).toHaveLength(1);
    expect(items[0].name).toBe(burger.name);
    expect(items[0].quantity).toBe(2);

    await restored.store.getState().loadForOwner('user-2');
    expect(restored.store.getState().items).toEqual([]);
  });

  it('a different restaurant requires confirmation before replacement', async () => {
    const { store } = build();
    await store.getState().loadForOwner('user-1');
    await store.getState().addItem(burger);

    expect(await store.getState().addItem(pizza)).toBe('restaurantConflict');
    expect(store.getState().items).toHaveLength(1);
    expect(store.getState().items[0].menuItemId).toBe(burger.menuItemId);

    expect(await store.getState().addItem(pizza, { replaceRestaurantCart: true })).toBe('replacedRestaurant');
    expect(store.getState().items).toHaveLength(1);
    expect(store.getState().items[0].menuItemId).toBe('pizza-1');
  });

  it('quantity changes, removal, and clear are persisted', async () => {
    const storage = new MemoryCartStorage<CartItem>();
    const { store } = build(storage);
    await store.getState().loadForOwner('user-1');
    await store.getState().addItem(burger);

    await store.getState().increment(burger.menuItemId);
    await store.getState().decrement(burger.menuItemId);
    expect(store.getState().items[0].quantity).toBe(1);

    await store.getState().remove(burger.menuItemId);
    expect(store.getState().items).toHaveLength(0);

    await store.getState().addItem(burger);
    await store.getState().clear();

    const restored = build(storage);
    await restored.store.getState().loadForOwner('user-1');
    expect(restored.store.getState().items).toEqual([]);
  });

  it('decrement never drops quantity below 1 -- removal is a separate, explicit action', async () => {
    const { store } = build();
    await store.getState().loadForOwner('user-1');
    await store.getState().addItem(burger);

    await store.getState().decrement(burger.menuItemId);

    expect(store.getState().items[0].quantity).toBe(1);
  });

  it('increment/decrement/remove on an item not in the cart are no-ops', async () => {
    const { store } = build();
    await store.getState().loadForOwner('user-1');

    await store.getState().increment('missing');
    await store.getState().decrement('missing');
    await store.getState().remove('missing');

    expect(store.getState().items).toEqual([]);
  });

  describe('maximum quantity clamp (99)', () => {
    it('clamps a large initial add to the maximum', async () => {
      const { store } = build();
      await store.getState().loadForOwner('user-1');

      expect(await store.getState().addItem(burger, { quantity: 150 })).toBe('added');
      expect(store.getState().items[0].quantity).toBe(FOOD_CART_MAXIMUM_QUANTITY);
    });

    it('adding more of an existing item clamps at the maximum rather than exceeding it', async () => {
      const { store } = build();
      await store.getState().loadForOwner('user-1');
      await store.getState().addItem(burger, { quantity: 95 });

      expect(await store.getState().addItem(burger, { quantity: 10 })).toBe('quantityIncreased');
      expect(store.getState().items[0].quantity).toBe(FOOD_CART_MAXIMUM_QUANTITY);
    });

    it('addItem reports maximumReached once already at the cap, without changing quantity', async () => {
      const { store } = build();
      await store.getState().loadForOwner('user-1');
      await store.getState().addItem(burger, { quantity: FOOD_CART_MAXIMUM_QUANTITY });

      expect(await store.getState().addItem(burger)).toBe('maximumReached');
      expect(store.getState().items[0].quantity).toBe(FOOD_CART_MAXIMUM_QUANTITY);
    });

    it('increment is a no-op once already at the cap', async () => {
      const { store } = build();
      await store.getState().loadForOwner('user-1');
      await store.getState().addItem(burger, { quantity: FOOD_CART_MAXIMUM_QUANTITY });

      await store.getState().increment(burger.menuItemId);

      expect(store.getState().items[0].quantity).toBe(FOOD_CART_MAXIMUM_QUANTITY);
    });
  });

  describe('CartItem.toJson / fromJson', () => {
    it('round-trips through JSON', () => {
      const json = cartItemToJson({ ...burger, quantity: 3 });
      expect(cartItemFromJson(json)).toEqual({ ...burger, quantity: 3 });
    });

    it('defaults a missing restaurantName/imageUrl on read, mirroring the Dart fallback', () => {
      const item = cartItemFromJson({
        menu_item_id: 'm-1',
        restaurant_id: 'r-1',
        restaurant_name: null,
        name: 'Fries',
        unit_price: 300,
        image_url: null,
        quantity: 1,
      });

      expect(item.restaurantName).toBe('Restaurant');
      expect(item.imageUrl).toBe('');
    });

    it('rejects a quantity below 1 or a negative unit price', () => {
      expect(() => cartItemFromJson({ ...cartItemToJson(burger), quantity: 0 })).toThrow();
      expect(() => cartItemFromJson({ ...cartItemToJson(burger), unit_price: -1 })).toThrow();
    });
  });
});
