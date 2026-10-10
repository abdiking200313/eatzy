/**
 * Ports `flutter_app/lib/services/food/presentation/cart_controller.dart`
 * (`CartController`) and `flutter_app/lib/services/food/models/
 * cart_item.dart` (`CartItem`) -- issue #376.
 *
 * Food has no separate cart/controller split the way grocery does
 * (`grocery-cart-store.ts`): quantity rules, restaurant-switching, totals,
 * and persistence all live directly on `CartController`, so they all live
 * directly on this one Zustand store too.
 *
 * Registration with `sessionResetRegistry` (mirrors grocery/pharmacy's own
 * registration, and Flutter's behavior once ported to this app's single
 * `AccountStateCoordinator` flow -- see `account-state-coordinator.ts` and
 * `session-store.ts`) is what makes the cart reload for the signed-in
 * owner on sign-in/session-restore and clear/reload to the guest cart on
 * sign-out, instead of leaking between accounts.
 */
import { create, type StoreApi, type UseBoundStore } from 'zustand';

import {
  ServicePricingRepository,
  useServicePricing,
  type ServicePricing,
} from '@/platform/pricing/service-pricing-repository';

import { AsyncStorageCartStorage, CartWriteQueue, GUEST_CART_OWNER, readCartLogged, type CartStorage } from './cart-storage';
import { sessionResetRegistry, type SessionResetRegistry } from './session-reset-registry';

/** Mirrors `CartController.maximumQuantity`. */
export const FOOD_CART_MAXIMUM_QUANTITY = 99;

/** The `service_pricing.service_id` this vertical's fee/tax estimate is read from -- see `ServicePricingRepository`. Mirrors `CartController.serviceId`. */
export const FOOD_SERVICE_ID = 'food' as const;

/** Mirrors `SharedPreferencesCartStorage`'s `keyPrefix: 'zivo.cart.v1'` for the food cart. */
export const FOOD_CART_KEY_PREFIX = 'zivo.cart.v1';

/** Ports `CartItem` (`flutter_app/lib/services/food/models/cart_item.dart`). */
export interface CartItem {
  menuItemId: string;
  restaurantId: string;
  restaurantName: string;
  name: string;
  /** Price in integer cents. */
  unitPrice: number;
  imageUrl: string;
  quantity: number;
}

/** Ports `CartItem.total`: `unitPrice * quantity`, in integer cents. */
export function cartItemTotal(item: CartItem): number {
  return item.unitPrice * item.quantity;
}

/** Ports `CartItem.toJson` -- key names must match exactly (shared with nothing else, but kept stable for forward/backward compatibility of a persisted cart). */
export function cartItemToJson(item: CartItem): Record<string, unknown> {
  return {
    menu_item_id: item.menuItemId,
    restaurant_id: item.restaurantId,
    restaurant_name: item.restaurantName,
    name: item.name,
    unit_price: item.unitPrice,
    image_url: item.imageUrl,
    quantity: item.quantity,
  };
}

/** Ports `CartItem.fromJson`, including its validation: throws on `quantity < 1` or `unitPrice < 0` (mirrors the Dart `FormatException`). */
export function cartItemFromJson(json: Record<string, unknown>): CartItem {
  const rawPrice = json.unit_price;
  const rawQuantity = json.quantity;
  const unitPrice = typeof rawPrice === 'number' ? Math.round(rawPrice) : parseInt(String(rawPrice), 10);
  const quantity = typeof rawQuantity === 'number' ? Math.trunc(rawQuantity) : parseInt(String(rawQuantity), 10);

  if (!Number.isFinite(quantity) || !Number.isFinite(unitPrice) || quantity < 1 || unitPrice < 0) {
    throw new Error('Invalid cart item values');
  }

  return {
    menuItemId: String(json.menu_item_id),
    restaurantId: String(json.restaurant_id),
    restaurantName: json.restaurant_name == null ? 'Restaurant' : String(json.restaurant_name),
    name: String(json.name),
    unitPrice,
    imageUrl: json.image_url == null ? '' : String(json.image_url),
    quantity,
  };
}

/** Ports `CartAddResult`. */
export type CartAddResult = 'added' | 'quantityIncreased' | 'replacedRestaurant' | 'restaurantConflict' | 'maximumReached';

export interface AddFoodCartItemOptions {
  /** Mirrors `addItem`'s `replaceRestaurantCart` parameter. */
  replaceRestaurantCart?: boolean;
  /** Number of units to add. Must be at least 1. Mirrors `addItem`'s `quantity` parameter. */
  quantity?: number;
}

export interface FoodCartState {
  items: CartItem[];
  ownerId: string | null;
  isLoading: boolean;
  /** Ports `CartController.loadForOwner`. */
  loadForOwner: (ownerId: string | null) => Promise<void>;
  /** Ports `CartController.addItem`. */
  addItem: (item: CartItem, options?: AddFoodCartItemOptions) => Promise<CartAddResult>;
  /** Ports `CartController.increment`. */
  increment: (menuItemId: string) => Promise<void>;
  /** Ports `CartController.decrement`. */
  decrement: (menuItemId: string) => Promise<void>;
  /** Ports `CartController.remove`. */
  remove: (menuItemId: string) => Promise<void>;
  /** Ports `CartController.clear`. */
  clear: () => Promise<void>;
}

export interface CreateFoodCartStoreOptions {
  /** Defaults to a real `AsyncStorageCartStorage<CartItem>` keyed by {@link FOOD_CART_KEY_PREFIX}. */
  storage?: CartStorage<CartItem>;
  /** Defaults to the shared `sessionResetRegistry` singleton -- pass a fresh one in a test to avoid sharing state with other tests/modules. */
  registry?: SessionResetRegistry;
}

export interface FoodCartStoreHandle {
  store: UseBoundStore<StoreApi<FoodCartState>>;
  /** Resolves once every cart write queued so far has been persisted. Mirrors `CartController`'s write-queue draining, exposed mainly for tests. */
  pendingWrite: () => Promise<void>;
  /** Stops listening for account changes. Mainly for tests -- the app-wide singleton below lives for the app's lifetime. */
  unregister: () => void;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

/**
 * Builds an independent food cart store wired to `options.storage`/
 * `options.registry` (real `AsyncStorage`/the shared registry by default).
 * Exists mainly so a test can build an isolated instance instead of sharing
 * the app-wide singleton -- see {@link useFoodCartStore} for the one the
 * app actually renders against.
 */
export function createFoodCartStore(options: CreateFoodCartStoreOptions = {}): FoodCartStoreHandle {
  const storage =
    options.storage ??
    new AsyncStorageCartStorage<CartItem>({
      keyPrefix: FOOD_CART_KEY_PREFIX,
      toJson: cartItemToJson,
      fromJson: cartItemFromJson,
    });
  const registry = options.registry ?? sessionResetRegistry;
  const writeQueue = new CartWriteQueue('FoodCartStore');
  let loadGeneration = 0;

  function storageOwner(ownerId: string | null): string {
    return ownerId ?? GUEST_CART_OWNER;
  }

  function persist(): Promise<void> {
    const owner = storageOwner(store.getState().ownerId);
    const snapshot = store.getState().items;
    return writeQueue.enqueue(() => storage.write(owner, snapshot));
  }

  const store = create<FoodCartState>((set, get) => ({
    items: [],
    ownerId: null,
    isLoading: false,

    loadForOwner: async (ownerId) => {
      const generation = ++loadGeneration;
      set({ ownerId, items: [], isLoading: true });

      const loadedItems = await readCartLogged(storage, storageOwner(ownerId), 'FoodCartStore');
      if (generation !== loadGeneration) {
        return;
      }

      set({ items: loadedItems, isLoading: false });
      // Warms (or refreshes) the delivery-fee/tax estimate in the
      // background; never throws -- mirrors `CartController._loadPricing`.
      void ServicePricingRepository.load(FOOD_SERVICE_ID);
    },

    addItem: async (item, addOptions = {}) => {
      const { replaceRestaurantCart = false, quantity = 1 } = addOptions;
      const items = get().items;
      const hasRestaurantConflict = items.length > 0 && items[0].restaurantId !== item.restaurantId;

      if (hasRestaurantConflict && !replaceRestaurantCart) {
        return 'restaurantConflict';
      }

      if (hasRestaurantConflict) {
        set({ items: [{ ...item, quantity: clamp(quantity, 1, FOOD_CART_MAXIMUM_QUANTITY) }] });
        await persist();
        return 'replacedRestaurant';
      }

      const existingIndex = items.findIndex((cartItem) => cartItem.menuItemId === item.menuItemId);
      if (existingIndex === -1) {
        set({ items: [...items, { ...item, quantity: clamp(quantity, 1, FOOD_CART_MAXIMUM_QUANTITY) }] });
        await persist();
        return 'added';
      }

      const existingItem = items[existingIndex];
      if (existingItem.quantity >= FOOD_CART_MAXIMUM_QUANTITY) {
        return 'maximumReached';
      }

      const nextItems = [...items];
      nextItems[existingIndex] = {
        ...existingItem,
        quantity: Math.min(existingItem.quantity + quantity, FOOD_CART_MAXIMUM_QUANTITY),
      };
      set({ items: nextItems });
      await persist();
      return 'quantityIncreased';
    },

    increment: async (menuItemId) => {
      const items = get().items;
      const index = items.findIndex((item) => item.menuItemId === menuItemId);
      if (index === -1 || items[index].quantity >= FOOD_CART_MAXIMUM_QUANTITY) {
        return;
      }

      const nextItems = [...items];
      nextItems[index] = { ...items[index], quantity: items[index].quantity + 1 };
      set({ items: nextItems });
      await persist();
    },

    decrement: async (menuItemId) => {
      const items = get().items;
      const index = items.findIndex((item) => item.menuItemId === menuItemId);
      if (index === -1 || items[index].quantity <= 1) {
        return;
      }

      const nextItems = [...items];
      nextItems[index] = { ...items[index], quantity: items[index].quantity - 1 };
      set({ items: nextItems });
      await persist();
    },

    remove: async (menuItemId) => {
      set({ items: get().items.filter((item) => item.menuItemId !== menuItemId) });
      await persist();
    },

    clear: async () => {
      if (get().items.length === 0) {
        return;
      }
      set({ items: [] });
      const owner = storageOwner(get().ownerId);
      await writeQueue.enqueue(() => storage.clear(owner));
    },
  }));

  const unregister = registry.register((nextOwnerId) => {
    void store.getState().loadForOwner(nextOwnerId);
  });

  return {
    store,
    pendingWrite: () => writeQueue.pending,
    unregister,
  };
}

const defaultFoodCartStore = createFoodCartStore();

/** The app-wide food cart store. Read it the way any Zustand store is read, e.g. `useFoodCartStore((state) => state.items)`. */
export const useFoodCartStore = defaultFoodCartStore.store;

/** Exposed for the rare direct (non-React) caller and for tests -- most code should just read {@link useFoodCartStore}. */
export const foodCartStore = defaultFoodCartStore;

// --- Derived totals -------------------------------------------------------
//
// Ports `CartController`'s `subtotal`/`itemCount`/`tax`/`deliveryFee`/
// `total` getters. Kept as pure functions (recomputed from `items`/
// `pricing` on every call) rather than stored, derived Zustand state, the
// same way the Dart getters are recomputed on every access rather than
// cached on the controller.

export interface FoodCartTotals {
  subtotal: number;
  itemCount: number;
  restaurantId: string | null;
  restaurantName: string | null;
  /** `null` until pricing has ever loaded -- an empty cart is always `0` regardless, since there is nothing to price. Mirrors `CartController.tax`. */
  tax: number | null;
  /** `null` until pricing has ever loaded -- an empty cart is always `0` regardless. Mirrors `CartController.deliveryFee`. */
  deliveryFee: number | null;
  /** `null` if either `tax` or `deliveryFee` is `null`. Mirrors `CartController.total`. */
  total: number | null;
}

/** Ports `CartController.subtotal`. */
export function selectFoodCartSubtotal(items: CartItem[]): number {
  return items.reduce((sum, item) => sum + cartItemTotal(item), 0);
}

/** Ports `CartController.itemCount`. */
export function selectFoodCartItemCount(items: CartItem[]): number {
  return items.reduce((sum, item) => sum + item.quantity, 0);
}

/**
 * Combines `items` with `pricing` (the last loaded `ServicePricing` for
 * `'food'`, or `undefined` if none has loaded yet) into the same shape
 * `CartController`'s getters expose. Rounded with `Math.round` at the point
 * it combines with other integer-cent values, matching `place_food_order`'s
 * own `round(v_subtotal * v_tax_rate)::integer`.
 */
export function computeFoodCartTotals(items: CartItem[], pricing: ServicePricing | undefined): FoodCartTotals {
  const subtotal = selectFoodCartSubtotal(items);
  const itemCount = selectFoodCartItemCount(items);
  const restaurantId = items.length === 0 ? null : items[0].restaurantId;
  const restaurantName = items.length === 0 ? null : items[0].restaurantName;

  if (items.length === 0) {
    return { subtotal: 0, itemCount: 0, restaurantId, restaurantName, tax: 0, deliveryFee: 0, total: 0 };
  }

  const tax = pricing == null ? null : Math.round(subtotal * pricing.taxRate);
  const deliveryFee = pricing == null ? null : pricing.deliveryFeeCents;
  const total = tax == null || deliveryFee == null ? null : subtotal + tax + deliveryFee;

  return { subtotal, itemCount, restaurantId, restaurantName, tax, deliveryFee, total };
}

/**
 * The hook a food cart/checkout screen uses to read live totals: subscribes
 * to this store's `items` and to the shared `service_pricing` query cache
 * (`useServicePricing`'s own queryKey) so it reflects a pricing refresh
 * triggered either by this hook or by `loadForOwner`'s background warm-up,
 * without either side needing to know about the other.
 */
export function useFoodCartTotals(): FoodCartTotals {
  const items = useFoodCartStore((state) => state.items);
  const pricingQuery = useServicePricing(FOOD_SERVICE_ID);
  const pricing = pricingQuery.data ?? ServicePricingRepository.peek(FOOD_SERVICE_ID);
  return computeFoodCartTotals(items, pricing);
}
