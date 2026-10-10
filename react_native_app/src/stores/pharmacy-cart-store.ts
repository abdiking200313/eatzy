/**
 * Ports the cart-scoped slice of
 * `flutter_app/lib/services/pharmacy/presentation/pharmacy_controller.dart`
 * (`PharmacyController`) -- issue #376. Pharmacy has no separate
 * `PharmacyCart` class the way grocery does (`grocery-cart-store.ts`): its
 * quantity rules, store-switching, totals, and persistence all live
 * directly on `PharmacyController` alongside catalog loading
 * (`loadProducts`/`loadMore`) and checkout (`placeDemoOrder`). Only the
 * cart-scoped pieces are ported here -- catalog/checkout belong to a later
 * issue (#379 covers the shared cart/checkout views); see this issue's
 * final report for the exact contract a catalog-loading hook should build
 * `PharmacyProduct` values against.
 *
 * `PharmacyProduct` is ported from
 * `flutter_app/lib/services/pharmacy/models/pharmacy_product.dart`;
 * `PharmacyCartItem` from `.../models/pharmacy_cart_item.dart` (an explicit
 * "Ports from Flutter" source for this issue).
 */
import { create, type StoreApi, type UseBoundStore } from 'zustand';

import {
  ServicePricingRepository,
  useServicePricing,
  type ServicePricing,
} from '@/platform/pricing/service-pricing-repository';

import { AsyncStorageCartStorage, CartWriteQueue, GUEST_CART_OWNER, readCartLogged, type CartStorage } from './cart-storage';
import { sessionResetRegistry, type SessionResetRegistry } from './session-reset-registry';

// --- Models ------------------------------------------------------------------

/** Ports `PharmacySaleType`. */
export type PharmacySaleType = 'overTheCounter' | 'prescriptionOnly' | 'regulated';

/** Ports `PharmacyProduct`. */
export interface PharmacyProduct {
  id: string;
  /** The pharmacy (`public.pharmacy_stores.id`) that stocks this product, scoping the customer-facing catalog and cart to a single pharmacy at a time. */
  storeId: string;
  name: string;
  description: string;
  category: string;
  /** Price in integer cents. */
  unitPrice: number;
  stockQuantity: number;
  saleType: PharmacySaleType;
  imageUrl?: string | null;
}

/** Ports `PharmacyProduct.isOverTheCounter`. */
export function isPharmacyProductOverTheCounter(product: PharmacyProduct): boolean {
  return product.saleType === 'overTheCounter';
}

/** Ports `PharmacyProduct.isAvailable`. */
export function isPharmacyProductAvailable(product: PharmacyProduct): boolean {
  return product.stockQuantity > 0;
}

/** Ports `PharmacyProduct.isLowStock`. */
export function isPharmacyProductLowStock(product: PharmacyProduct): boolean {
  return product.stockQuantity > 0 && product.stockQuantity <= 5;
}

/** Ports `PharmacyProduct.toJson` (the cart-persistence snapshot, not the Supabase row shape). */
export function pharmacyProductToJson(product: PharmacyProduct): Record<string, unknown> {
  return {
    id: product.id,
    store_id: product.storeId,
    name: product.name,
    description: product.description,
    category: product.category,
    unit_price: product.unitPrice,
    stock_quantity: product.stockQuantity,
    sale_type: product.saleType,
    image_url: product.imageUrl ?? null,
  };
}

/** Ports `PharmacyProduct.fromJson`. */
export function pharmacyProductFromJson(json: Record<string, unknown>): PharmacyProduct {
  const saleType = json.sale_type as PharmacySaleType;
  if (saleType !== 'overTheCounter' && saleType !== 'prescriptionOnly' && saleType !== 'regulated') {
    throw new Error(`Unsupported pharmacy sale type: ${String(json.sale_type)}`);
  }

  return {
    id: String(json.id),
    storeId: String(json.store_id),
    name: String(json.name),
    description: json.description == null ? '' : String(json.description),
    category: String(json.category),
    unitPrice: Math.trunc(Number(json.unit_price)),
    stockQuantity: Math.trunc(Number(json.stock_quantity)),
    saleType,
    imageUrl: json.image_url == null ? null : String(json.image_url),
  };
}

/** Ports `PharmacyCartItem`. */
export interface PharmacyCartItem {
  product: PharmacyProduct;
  quantity: number;
}

/** Ports `PharmacyCartItem.total`: in integer cents. */
export function pharmacyCartItemTotal(item: PharmacyCartItem): number {
  return item.product.unitPrice * item.quantity;
}

/** Ports `PharmacyCartItem.toJson`. */
export function pharmacyCartItemToJson(item: PharmacyCartItem): Record<string, unknown> {
  return { product: pharmacyProductToJson(item.product), quantity: item.quantity };
}

/** Ports `PharmacyCartItem.fromJson`, including its validation: throws when `quantity < 1` (mirrors the Dart `FormatException`). */
export function pharmacyCartItemFromJson(json: Record<string, unknown>): PharmacyCartItem {
  const rawQuantity = json.quantity;
  const quantity = typeof rawQuantity === 'number' ? Math.trunc(rawQuantity) : parseInt(String(rawQuantity), 10);
  if (!Number.isFinite(quantity) || quantity < 1) {
    throw new Error('Invalid pharmacy cart item quantity');
  }

  return {
    product: pharmacyProductFromJson(json.product as Record<string, unknown>),
    quantity,
  };
}

// --- Cart store --------------------------------------------------------------

/** Ports `PharmacyCartAddResult`. */
export type PharmacyCartAddResult =
  | 'added'
  | 'quantityIncreased'
  | 'notOverTheCounter'
  | 'unavailable'
  | 'maximumStockReached'
  | 'storeConflict';

/** The `service_pricing.service_id` this vertical's fee estimate is read from -- see `ServicePricingRepository`. Mirrors `PharmacyController.serviceId`. */
export const PHARMACY_SERVICE_ID = 'pharmacy' as const;

/** Mirrors `SharedPreferencesCartStorage`'s `keyPrefix: 'zivo.cart.v1.pharmacy'`. */
export const PHARMACY_CART_KEY_PREFIX = 'zivo.cart.v1.pharmacy';

export interface AddPharmacyProductOptions {
  /** Mirrors `addProduct`'s `replaceStoreCart` parameter. */
  replaceStoreCart?: boolean;
  /** Mirrors `addProduct`'s `quantity` parameter. Must be at least 1. */
  quantity?: number;
}

export interface PharmacyCartState {
  items: PharmacyCartItem[];
  ownerId: string | null;
  isLoading: boolean;
  /** Ports `PharmacyController.loadForOwner` (the cart half). */
  loadForOwner: (ownerId: string | null) => Promise<void>;
  /** Ports `PharmacyController.addProduct`. Synchronous, like the Dart method -- persistence happens in the background (fire-and-forget), not awaited. */
  addProduct: (product: PharmacyProduct, options?: AddPharmacyProductOptions) => PharmacyCartAddResult;
  /** Ports `PharmacyController.increment`. */
  increment: (productId: string) => void;
  /**
   * Ports `PharmacyController.decrement` -- note this removes the item
   * entirely (not a no-op) once its quantity would drop to zero, unlike
   * the food cart's `decrement`. This is a deliberate difference from food,
   * not a bug -- see the Dart source.
   */
  decrement: (productId: string) => void;
  /** Ports `PharmacyController.removeProduct`. */
  removeProduct: (productId: string) => void;
  /** Ports `PharmacyController.clearCart`. */
  clearCart: () => void;
}

export interface CreatePharmacyCartStoreOptions {
  /** Defaults to a real `AsyncStorageCartStorage<PharmacyCartItem>` keyed by {@link PHARMACY_CART_KEY_PREFIX}. */
  storage?: CartStorage<PharmacyCartItem>;
  /** Defaults to the shared `sessionResetRegistry` singleton -- pass a fresh one in a test to avoid sharing state with other tests/modules. */
  registry?: SessionResetRegistry;
}

export interface PharmacyCartStoreHandle {
  store: UseBoundStore<StoreApi<PharmacyCartState>>;
  /** Resolves once every cart write queued so far has been persisted. Exposed mainly for tests. */
  pendingWrite: () => Promise<void>;
  /** Stops listening for account changes. Mainly for tests -- the app-wide singleton below lives for the app's lifetime. */
  unregister: () => void;
}

/**
 * Builds an independent pharmacy cart store wired to `options.storage`/
 * `options.registry` (real `AsyncStorage`/the shared registry by default).
 * Exists mainly so a test can build an isolated instance instead of sharing
 * the app-wide singleton -- see {@link usePharmacyCartStore} for the one
 * the app actually renders against.
 */
export function createPharmacyCartStore(options: CreatePharmacyCartStoreOptions = {}): PharmacyCartStoreHandle {
  const storage =
    options.storage ??
    new AsyncStorageCartStorage<PharmacyCartItem>({
      keyPrefix: PHARMACY_CART_KEY_PREFIX,
      toJson: pharmacyCartItemToJson,
      fromJson: pharmacyCartItemFromJson,
    });
  const registry = options.registry ?? sessionResetRegistry;
  const writeQueue = new CartWriteQueue('PharmacyCartStore');
  let loadGeneration = 0;

  function storageOwner(ownerId: string | null): string {
    return ownerId ?? GUEST_CART_OWNER;
  }

  function persist(): Promise<void> {
    const owner = storageOwner(store.getState().ownerId);
    const snapshot = store.getState().items;
    return writeQueue.enqueue(() => storage.write(owner, snapshot));
  }

  const store = create<PharmacyCartState>((set, get) => ({
    items: [],
    ownerId: null,
    isLoading: false,

    loadForOwner: async (ownerId) => {
      const generation = ++loadGeneration;
      set({ ownerId, items: [], isLoading: true });

      const loadedItems = await readCartLogged(storage, storageOwner(ownerId), 'PharmacyCartStore');
      if (generation !== loadGeneration) {
        return;
      }

      set({ items: loadedItems, isLoading: false });
      // Warms (or refreshes) the delivery-fee estimate in the background;
      // never throws -- mirrors `PharmacyController._loadPricing`.
      void ServicePricingRepository.load(PHARMACY_SERVICE_ID);
    },

    addProduct: (product, addOptions = {}) => {
      const { replaceStoreCart = false, quantity = 1 } = addOptions;
      if (!isPharmacyProductOverTheCounter(product)) {
        return 'notOverTheCounter';
      }
      if (!isPharmacyProductAvailable(product)) {
        return 'unavailable';
      }

      let items = get().items;
      const hasStoreConflict = items.length > 0 && items[0].product.storeId !== product.storeId;
      if (hasStoreConflict && !replaceStoreCart) {
        return 'storeConflict';
      }
      if (hasStoreConflict) {
        items = [];
      }

      const index = items.findIndex((item) => item.product.id === product.id);
      if (index === -1) {
        if (quantity > product.stockQuantity) {
          return 'maximumStockReached';
        }
        set({ items: [...items, { product, quantity }] });
        void persist();
        return 'added';
      }

      const item = items[index];
      if (item.quantity + quantity > product.stockQuantity) {
        return 'maximumStockReached';
      }
      const nextItems = items.map((existing, i) => (i === index ? { ...existing, quantity: existing.quantity + quantity } : existing));
      set({ items: nextItems });
      void persist();
      return 'quantityIncreased';
    },

    increment: (productId) => {
      const items = get().items;
      const index = items.findIndex((item) => item.product.id === productId);
      if (index === -1) {
        return;
      }

      const item = items[index];
      if (item.quantity >= item.product.stockQuantity) {
        return;
      }

      const nextItems = items.map((existing, i) => (i === index ? { ...existing, quantity: existing.quantity + 1 } : existing));
      set({ items: nextItems });
      void persist();
    },

    decrement: (productId) => {
      const items = get().items;
      const index = items.findIndex((item) => item.product.id === productId);
      if (index === -1) {
        return;
      }

      const item = items[index];
      if (item.quantity <= 1) {
        get().removeProduct(productId);
        return;
      }

      const nextItems = items.map((existing, i) => (i === index ? { ...existing, quantity: existing.quantity - 1 } : existing));
      set({ items: nextItems });
      void persist();
    },

    removeProduct: (productId) => {
      const items = get().items;
      const nextItems = items.filter((item) => item.product.id !== productId);
      if (nextItems.length !== items.length) {
        set({ items: nextItems });
        void persist();
      }
    },

    clearCart: () => {
      if (get().items.length === 0) {
        return;
      }
      set({ items: [] });
      void persist();
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

const defaultPharmacyCartStore = createPharmacyCartStore();

/** The app-wide pharmacy cart store. Read it the way any Zustand store is read, e.g. `usePharmacyCartStore((state) => state.items)`. */
export const usePharmacyCartStore = defaultPharmacyCartStore.store;

/** Exposed for the rare direct (non-React) caller and for tests -- most code should just read {@link usePharmacyCartStore}. */
export const pharmacyCartStore = defaultPharmacyCartStore;

// --- Derived totals ----------------------------------------------------------

export interface PharmacyCartTotals {
  subtotal: number;
  itemCount: number;
  storeId: string | null;
  /** `null` until pricing has ever loaded -- an empty cart is always `0` regardless. Mirrors `PharmacyController.deliveryFee`. Pharmacy charges no tax. */
  deliveryFee: number | null;
  /** `null` if `deliveryFee` is `null`. Mirrors `PharmacyController.total`. */
  total: number | null;
}

/** Ports `PharmacyController.subtotal`. */
export function selectPharmacyCartSubtotal(items: PharmacyCartItem[]): number {
  return items.reduce((sum, item) => sum + pharmacyCartItemTotal(item), 0);
}

/** Ports `PharmacyController.itemCount`. */
export function selectPharmacyCartItemCount(items: PharmacyCartItem[]): number {
  return items.reduce((sum, item) => sum + item.quantity, 0);
}

/** Ports the pharmacy counterpart of `GroceryCart.storeId` (the cart is scoped to one pharmacy at a time -- see `PharmacyCartAddResult.storeConflict`). */
export function selectPharmacyCartStoreId(items: PharmacyCartItem[]): string | null {
  return items.length === 0 ? null : items[0].product.storeId;
}

/** Combines `items` with `pricing` (the last loaded `ServicePricing` for `'pharmacy'`, or `undefined` if none has loaded yet) into the same shape `PharmacyController`'s getters expose. */
export function computePharmacyCartTotals(items: PharmacyCartItem[], pricing: ServicePricing | undefined): PharmacyCartTotals {
  const subtotal = selectPharmacyCartSubtotal(items);
  const itemCount = selectPharmacyCartItemCount(items);
  const storeId = selectPharmacyCartStoreId(items);

  if (items.length === 0) {
    return { subtotal: 0, itemCount: 0, storeId, deliveryFee: 0, total: 0 };
  }

  const deliveryFee = pricing == null ? null : pricing.deliveryFeeCents;
  const total = deliveryFee == null ? null : subtotal + deliveryFee;
  return { subtotal, itemCount, storeId, deliveryFee, total };
}

/**
 * The hook a pharmacy cart/checkout screen uses to read live totals -- see
 * {@link useFoodCartTotals}'s doc comment in `food-cart-store.ts` for why
 * this reads `service_pricing` through `useServicePricing` instead of a
 * one-off query.
 */
export function usePharmacyCartTotals(): PharmacyCartTotals {
  const items = usePharmacyCartStore((state) => state.items);
  const pricingQuery = useServicePricing(PHARMACY_SERVICE_ID);
  const pricing = pricingQuery.data ?? ServicePricingRepository.peek(PHARMACY_SERVICE_ID);
  return computePharmacyCartTotals(items, pricing);
}
