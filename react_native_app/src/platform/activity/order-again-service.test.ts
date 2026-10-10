/**
 * Ports `flutter_app/test/order_again_test.dart` (issue #397 / P8-01).
 *
 * - "OrderAgainService.fillCart": ported one-for-one against the real,
 *   already-ported cart stores (isolated instances with in-memory storage).
 * - "Order details 'Order again'": the Dart cases pump `TrackOrderScreen`,
 *   which is ported by #398 / P8-02. Their behavior -- ask before replacing
 *   a non-empty cart, cancel leaves it alone, an empty cart fills without
 *   asking, nothing available says so and stays -- lives in `runOrderAgain`
 *   (the screen-independent half of `_orderAgainPressed`), so they're
 *   ported against that here, with the dialog/snackbar/navigation as fakes.
 *
 * Also covers `SupabaseOrderAgainRepository.loadBasket` against the fake
 * Supabase client (no Dart test of its own).
 */
import { createFakeSupabaseClient, fakeSupabaseOk } from '@/test-utils/fake-supabase-client';
import { MemoryCartStorage } from '@/test-utils/memory-cart-storage';
import type { ActivityItem } from '@/platform/activity/api/activity-item';
import { ErrorReporting, NoopErrorReporter, type ErrorReporter } from '@/platform/error-reporting/error-reporter';
import { AppRoutes } from '@/platform/navigation/app-routes';
import { queryClient } from '@/platform/query/query-client';
import { createFoodCartStore, selectFoodCartSubtotal, type CartItem } from '@/stores/food-cart-store';
import { createGroceryCartStore, type GroceryProduct } from '@/stores/grocery-cart-store';
import { createPharmacyCartStore, type PharmacyProduct } from '@/stores/pharmacy-cart-store';
import { SessionResetRegistry } from '@/stores/session-reset-registry';

import { SupabaseOrderAgainRepository, type OrderAgainSource, type ReorderBasket } from './api/order-again-repository';
import { groceryCartRouteFor, OrderAgainService, runOrderAgain } from './order-again-service';

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

const pastBurger: CartItem = {
  menuItemId: 'burger-1',
  restaurantId: 'restaurant-1',
  restaurantName: 'Test Kitchen',
  name: 'Classic Burger',
  unitPrice: 1200,
  imageUrl: '',
  quantity: 2,
};
const otherRestaurantItem: CartItem = {
  menuItemId: 'soup-9',
  restaurantId: 'restaurant-9',
  restaurantName: 'Other Place',
  name: 'Lentil Soup',
  unitPrice: 500,
  imageUrl: '',
  quantity: 1,
};
const rice: GroceryProduct = {
  id: 'bakaal-rice',
  storeId: 'bakaal',
  name: 'Rice',
  description: '',
  unitPrice: 500,
  pricingUnit: 'each',
  stockState: 'inStock',
  availableQuantity: 10,
  icon: '🍚',
};
const paracetamol: PharmacyProduct = {
  id: 'paracetamol',
  storeId: 'pharmacy-1',
  name: 'Paracetamol',
  description: '',
  category: 'Pain relief',
  unitPrice: 300,
  stockQuantity: 20,
  saleType: 'overTheCounter',
};
const foodOrder: ActivityItem = {
  id: 'order-1',
  serviceId: 'food',
  title: 'Test Kitchen',
  status: 'Delivered',
  occurredAt: new Date('2026-09-20T00:00:00Z'),
  amount: 2400,
  detailsRoute: AppRoutes.food,
};

let foodCart: ReturnType<typeof createFoodCartStore>;
let grocery: ReturnType<typeof createGroceryCartStore>;
let pharmacy: ReturnType<typeof createPharmacyCartStore>;
let originalReporter: ErrorReporter;

beforeEach(async () => {
  const registry = new SessionResetRegistry();
  foodCart = createFoodCartStore({ storage: new MemoryCartStorage(), registry });
  grocery = createGroceryCartStore('grocery', { storage: new MemoryCartStorage(), registry });
  pharmacy = createPharmacyCartStore({ storage: new MemoryCartStorage(), registry });
  await foodCart.store.getState().loadForOwner('user-1');
  await grocery.store.getState().loadForOwner('user-1');
  await pharmacy.store.getState().loadForOwner('user-1');
  originalReporter = ErrorReporting.instance;
  ErrorReporting.instance = new NoopErrorReporter();
});

afterEach(() => {
  ErrorReporting.instance = originalReporter;
  queryClient.clear();
});

function service(basket: ReorderBasket | null) {
  return new OrderAgainService({
    repository: { loadBasket: async () => basket },
    foodCart: foodCart.store,
    groceryCart: () => grocery.store,
    pharmacyCart: pharmacy.store,
  });
}

describe('OrderAgainService.fillCart', () => {
  it('food: replaces the cart with the past items at their quantities', async () => {
    await foodCart.store.getState().addItem(otherRestaurantItem);
    const basket: ReorderBasket = { kind: 'food', items: [pastBurger], skippedNames: ['Fries'] };

    expect(service(basket).wouldReplaceCart(basket)).toBe(true);
    const route = await service(basket).fillCart(basket);

    expect(route).toBe(AppRoutes.foodCart);
    const items = foodCart.store.getState().items;
    expect(items).toHaveLength(1);
    expect(items[0].menuItemId).toBe('burger-1');
    expect(items[0].quantity).toBe(2);
    // Today's price, carried in the basket, is what the cart uses.
    expect(selectFoodCartSubtotal(items)).toBe(2400);
  });

  it('grocery: fills the grocery cart', async () => {
    const basket: ReorderBasket = { kind: 'grocery', storeType: 'grocery', lines: [{ product: rice, quantity: 3 }], skippedNames: [] };

    expect(service(basket).wouldReplaceCart(basket)).toBe(false);
    const route = await service(basket).fillCart(basket);

    expect(route).toBe(AppRoutes.groceryCart);
    expect(grocery.store.getState().lines).toHaveLength(1);
    expect(grocery.store.getState().lines[0].product.id).toBe('bakaal-rice');
    expect(grocery.store.getState().lines[0].quantity).toBe(3);
  });

  it('pharmacy: fills the pharmacy cart', async () => {
    const basket: ReorderBasket = { kind: 'pharmacy', lines: [{ product: paracetamol, quantity: 2 }], skippedNames: [] };

    const route = await service(basket).fillCart(basket);

    expect(route).toBe(AppRoutes.pharmacyCart);
    expect(pharmacy.store.getState().items).toHaveLength(1);
    expect(pharmacy.store.getState().items[0].product.id).toBe('paracetamol');
    expect(pharmacy.store.getState().items[0].quantity).toBe(2);
  });

  it('routes Fresh Meat and Electronics baskets to their own carts', () => {
    expect(groceryCartRouteFor('fresh_meat')).toBe(AppRoutes.freshMeatCart);
    expect(groceryCartRouteFor('electronics')).toBe(AppRoutes.electronicsCart);
  });

  // Ports grocery_store_type_test.dart's "Order again puts a Fresh Meat order
  // back into the Fresh Meat cart" (issue #396 parity).
  it('puts a Fresh Meat order back into the Fresh Meat cart, leaving the grocery cart alone', async () => {
    const meat = createGroceryCartStore('fresh_meat', { storage: new MemoryCartStorage(), registry: new SessionResetRegistry() });
    await meat.store.getState().loadForOwner('user-1');
    const goat: GroceryProduct = { ...rice, id: 'goat', storeId: 'butcher', name: 'Goat meat', pricingUnit: 'kilogram' };
    const basket: ReorderBasket = { kind: 'grocery', storeType: 'fresh_meat', lines: [{ product: goat, quantity: 2 }], skippedNames: [] };
    const orderAgain = new OrderAgainService({
      repository: { loadBasket: async () => basket },
      foodCart: foodCart.store,
      groceryCart: (storeType) => (storeType === 'fresh_meat' ? meat.store : grocery.store),
      pharmacyCart: pharmacy.store,
    });

    const route = await orderAgain.fillCart(basket);

    expect(route).toBe(AppRoutes.freshMeatCart);
    expect(meat.store.getState().lines).toHaveLength(1);
    expect(meat.store.getState().lines[0].product.id).toBe('goat');
    expect(meat.store.getState().lines[0].quantity).toBe(2);
    expect(grocery.store.getState().lines).toEqual([]);
  });
});

describe('Order details "Order again" (runOrderAgain)', () => {
  function run(basket: ReorderBasket | null, confirm: boolean) {
    const messages: string[] = [];
    const routes: string[] = [];
    const confirmReplace = jest.fn(async () => confirm);
    const result = runOrderAgain({
      service: service(basket),
      item: foodOrder,
      confirmReplace,
      showMessage: (message) => messages.push(message),
      navigate: (route) => routes.push(route),
    });
    return { result, messages, routes, confirmReplace };
  }

  it('asks before replacing a non-empty cart, then fills it, lists skipped items and opens the cart', async () => {
    await foodCart.store.getState().addItem(otherRestaurantItem);

    const { result, messages, routes, confirmReplace } = run({ kind: 'food', items: [pastBurger], skippedNames: ['Fries'] }, true);

    await expect(result).resolves.toBe('filled');
    expect(confirmReplace).toHaveBeenCalledTimes(1);
    expect(routes).toEqual([AppRoutes.foodCart]);
    expect(messages).toEqual(['No longer available: Fries']);
    expect(foodCart.store.getState().items[0].menuItemId).toBe('burger-1');
  });

  it('cancelling the replace prompt leaves the cart alone', async () => {
    await foodCart.store.getState().addItem(otherRestaurantItem);

    const { result, routes } = run({ kind: 'food', items: [pastBurger], skippedNames: [] }, false);

    await expect(result).resolves.toBe('cancelled');
    expect(routes).toEqual([]);
    expect(foodCart.store.getState().items[0].menuItemId).toBe('soup-9');
  });

  it('an empty cart is filled without asking', async () => {
    const { result, routes, confirmReplace } = run({ kind: 'food', items: [pastBurger], skippedNames: [] }, true);

    await expect(result).resolves.toBe('filled');
    expect(confirmReplace).not.toHaveBeenCalled();
    expect(routes).toEqual([AppRoutes.foodCart]);
  });

  it('when nothing is available any more, says so and stays', async () => {
    const { result, messages, routes } = run({ kind: 'food', items: [], skippedNames: ['Classic Burger'] }, true);

    await expect(result).resolves.toBe('nothingAvailable');
    expect(messages).toEqual(['None of these items can be ordered right now.']);
    expect(routes).toEqual([]);
    expect(foodCart.store.getState().items).toEqual([]);
  });

  it('an order that cannot be loaded says so', async () => {
    const { result, messages, routes } = run(null, true);

    await expect(result).resolves.toBe('loadFailed');
    expect(messages).toEqual(['This order could not be loaded. Try again.']);
    expect(routes).toEqual([]);
  });
});

describe('SupabaseOrderAgainRepository.loadBasket', () => {
  function repository() {
    const client = createFakeSupabaseClient();
    return { client, repo: new SupabaseOrderAgainRepository(client as unknown as OrderAgainSource) };
  }

  it("food: matches past lines against today's menu, at today's price, skipping what's gone", async () => {
    const { client, repo } = repository();
    client.queueTableResponse(
      'food_orders',
      fakeSupabaseOk({
        restaurant_id: 'restaurant-1',
        restaurant_name: 'Test Kitchen',
        food_order_items: [
          { menu_item_id: 'burger-1', item_name: 'Classic Burger', quantity: 2 },
          { menu_item_id: 'fries-1', item_name: 'Fries', quantity: 1 },
        ],
      }),
    );
    client.queueTableResponse('menu_items', fakeSupabaseOk([{ id: 'burger-1', name: 'Classic Burger', price: 1300, image_url: null, restaurant_id: 'restaurant-1' }]));
    client.queueTableResponse('restaurants', fakeSupabaseOk({ id: 'restaurant-1' }));

    const basket = await repo.loadBasket({ serviceId: 'food', orderId: 'order-1' });

    expect(basket).toEqual({
      kind: 'food',
      items: [{ ...pastBurger, unitPrice: 1300 }],
      skippedNames: ['Fries'],
    });
  });

  it('food: skips everything when the restaurant is closed', async () => {
    const { client, repo } = repository();
    client.queueTableResponse(
      'food_orders',
      fakeSupabaseOk({ restaurant_id: 'r', restaurant_name: 'R', food_order_items: [{ menu_item_id: 'burger-1', item_name: 'Classic Burger', quantity: 1 }] }),
    );
    client.queueTableResponse('menu_items', fakeSupabaseOk([{ id: 'burger-1', name: 'Classic Burger', price: 1300, image_url: null }]));
    client.queueTableResponse('restaurants', fakeSupabaseOk(null));

    const basket = await repo.loadBasket({ serviceId: 'food', orderId: 'order-1' });

    expect(basket).toMatchObject({ kind: 'food', items: [], skippedNames: ['Classic Burger'] });
  });

  it("grocery: caps quantities at today's stock and picks the store type's cart", async () => {
    const { client, repo } = repository();
    client.queueTableResponse(
      'grocery_orders',
      fakeSupabaseOk({ store_id: 'butcher', grocery_order_items: [{ product_id: 'beef', product_name: 'Beef', quantity: 4 }] }),
    );
    client.queueTableResponse(
      'grocery_products',
      fakeSupabaseOk([
        {
          id: 'beef',
          store_id: 'butcher',
          name: 'Beef',
          description: null,
          unit_price: 1500,
          pricing_unit: 'kilogram',
          quantity_step: 0.5,
          available_quantity: 2.5,
          low_stock_threshold: 1,
          icon: null,
          image_url: null,
          grocery_categories: null,
        },
      ]),
    );
    client.queueTableResponse('grocery_stores', fakeSupabaseOk({ id: 'butcher', store_type: 'fresh_meat' }));

    const basket = await repo.loadBasket({ serviceId: 'grocery', orderId: 'order-1' });

    expect(basket?.kind).toBe('grocery');
    if (basket?.kind !== 'grocery') return;
    expect(basket.storeType).toBe('fresh_meat');
    expect(basket.lines.map((line) => [line.product.id, line.quantity])).toEqual([['beef', 2.5]]);
  });

  it('pharmacy: only over-the-counter products in stock come back, capped at stock', async () => {
    const { client, repo } = repository();
    client.queueTableResponse(
      'pharmacy_orders',
      fakeSupabaseOk({
        pharmacy_order_items: [
          { product_id: 'paracetamol', product_name: 'Paracetamol', quantity: 30 },
          { product_id: 'amoxicillin', product_name: 'Amoxicillin', quantity: 1 },
        ],
      }),
    );
    client.queueTableResponse(
      'pharmacy_products',
      fakeSupabaseOk([
        {
          id: 'paracetamol',
          name: 'Paracetamol',
          description: null,
          unit_price: 300,
          stock_quantity: 20,
          sale_type: 'otc',
          image_url: null,
          store_id: 'pharmacy-1',
          pharmacy_categories: { id: 'c1', name: 'Pain relief' },
        },
      ]),
    );

    const basket = await repo.loadBasket({ serviceId: 'pharmacy', orderId: 'order-1' });

    expect(basket).toEqual({ kind: 'pharmacy', lines: [{ product: { ...paracetamol, imageUrl: null }, quantity: 20 }], skippedNames: ['Amoxicillin'] });
  });

  it('returns null for a missing order or an unknown service', async () => {
    const { client, repo } = repository();
    client.queueTableResponse('food_orders', fakeSupabaseOk(null));

    await expect(repo.loadBasket({ serviceId: 'food', orderId: 'missing' })).resolves.toBeNull();
    await expect(repo.loadBasket({ serviceId: 'unknown', orderId: 'x' })).resolves.toBeNull();
  });
});
