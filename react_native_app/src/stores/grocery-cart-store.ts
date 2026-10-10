/**
 * Ports `flutter_app/lib/services/grocery/presentation/grocery_cart.dart`
 * (`GroceryCart`) -- issue #376. Just the cart/quantity-step rules and
 * persistence `GroceryCart` itself owns, not catalog loading
 * (`grocery_catalog.dart`) or checkout (`grocery_checkout.dart`), which
 * belong to a later issue (#379 covers the shared cart/checkout views).
 *
 * `GroceryProduct`/`GroceryCartLine` below are ported from
 * `flutter_app/lib/services/grocery/models/grocery_models.dart`, narrowed to
 * the fields the cart itself needs (quantity-step rules, availability,
 * persistence) -- a future catalog-loading hook (#379) should build/accept
 * values of this exact shape; see this issue's final report for the precise
 * contract.
 *
 * Grocery, Fresh Meat, and Electronics all run on this same cart engine but
 * each keeps its own cart (`GroceryStoreType` -- "owner decision,
 * 2026-09-25" per the Dart source), so this module exports three
 * independent store singletons, one per `GroceryStoreType`, each with its
 * own persistence key and its own `sessionResetRegistry` registration --
 * mirrors `AppServices._buildGroceryController`'s per-`GroceryStoreType`
 * `SharedPreferencesCartStorage` construction.
 */
import { create, type StoreApi, type UseBoundStore } from 'zustand';

import {
  ServicePricingRepository,
  useServicePricing,
  type ServicePricing,
} from '@/platform/pricing/service-pricing-repository';

import { AsyncStorageCartStorage, CartWriteQueue, GUEST_CART_OWNER, readCartLogged, type CartStorage } from './cart-storage';
import { sessionResetRegistry, type SessionResetRegistry } from './session-reset-registry';

// --- Models ----------------------------------------------------------------

/** Ports `GroceryPricingUnit`. */
export type GroceryPricingUnit = 'each' | 'kilogram';

/** Ports `GroceryStockState`. */
export type GroceryStockState = 'inStock' | 'lowStock' | 'outOfStock';

/**
 * Which customer category lists a grocery store
 * (`grocery_stores.store_type`). Fresh Meat and Electronics run on the
 * grocery engine — same cart, checkout and order RPC — and only differ in
 * which store list shows them. Ports `GroceryStoreType.dbValue`.
 */
export type GroceryStoreType = 'grocery' | 'fresh_meat' | 'electronics';

export const GROCERY_STORE_TYPES: readonly GroceryStoreType[] = ['grocery', 'fresh_meat', 'electronics'];

/** Ports `GroceryProduct`, narrowed to the fields the cart itself needs -- see this file's top comment. */
export interface GroceryProduct {
  id: string;
  storeId: string;
  name: string;
  description: string;
  /** Price in integer cents, per `pricingUnit` (each item, or per kilogram). */
  unitPrice: number;
  pricingUnit: GroceryPricingUnit;
  stockState: GroceryStockState;
  availableQuantity: number;
  icon: string;
  imageUrl?: string | null;
  categoryName?: string | null;
  categorySortOrder?: number;
}

/** Ports `GroceryProduct.quantityStep`: one item, or 0.5 kg per step. */
export function groceryQuantityStep(pricingUnit: GroceryPricingUnit): number {
  return pricingUnit === 'each' ? 1 : 0.5;
}

/** Ports `GroceryProduct.isAvailable`. */
export function isGroceryProductAvailable(product: GroceryProduct): boolean {
  return product.stockState !== 'outOfStock' && product.availableQuantity >= groceryQuantityStep(product.pricingUnit);
}

/** Ports `GroceryProduct.toJson` (the cart-persistence snapshot, not the Supabase row shape). */
export function groceryProductToJson(product: GroceryProduct): Record<string, unknown> {
  return {
    id: product.id,
    store_id: product.storeId,
    name: product.name,
    description: product.description,
    unit_price: product.unitPrice,
    pricing_unit: product.pricingUnit,
    stock_state: product.stockState,
    available_quantity: product.availableQuantity,
    icon: product.icon,
    image_url: product.imageUrl ?? null,
    category_name: product.categoryName ?? null,
    category_sort_order: product.categorySortOrder ?? 0,
  };
}

/** Ports `GroceryProduct.fromJson`. */
export function groceryProductFromJson(json: Record<string, unknown>): GroceryProduct {
  const pricingUnit = json.pricing_unit as GroceryPricingUnit;
  if (pricingUnit !== 'each' && pricingUnit !== 'kilogram') {
    throw new Error(`Unsupported grocery pricing unit: ${String(json.pricing_unit)}`);
  }
  const stockState = json.stock_state as GroceryStockState;
  if (stockState !== 'inStock' && stockState !== 'lowStock' && stockState !== 'outOfStock') {
    throw new Error(`Unsupported grocery stock state: ${String(json.stock_state)}`);
  }

  return {
    id: String(json.id),
    storeId: String(json.store_id),
    name: String(json.name),
    description: json.description == null ? '' : String(json.description),
    unitPrice: Math.max(0, Math.round(Number(json.unit_price))),
    pricingUnit,
    stockState,
    availableQuantity: Number(json.available_quantity),
    icon: json.icon == null || json.icon === '' ? '🛒' : String(json.icon),
    imageUrl: json.image_url == null ? null : String(json.image_url),
    // Optional: carts persisted before categories existed lack both keys.
    categoryName: json.category_name == null ? null : String(json.category_name),
    categorySortOrder: typeof json.category_sort_order === 'number' ? json.category_sort_order : 0,
  };
}

/** Ports `GroceryCartLine`. */
export interface GroceryCartLine {
  product: GroceryProduct;
  quantity: number;
}

/** Ports `GroceryCartLine.total`: in integer cents, rounded since `unitPrice` (cents) times a fractional-kilogram `quantity` can land on a fractional cent. */
export function groceryCartLineTotal(line: GroceryCartLine): number {
  return Math.round(line.product.unitPrice * line.quantity);
}

/** Ports `GroceryCartLine.quantityLabel`: `"1.5 kg"` for weighed products, `"2"` for everything else. */
export function groceryQuantityLabel(line: GroceryCartLine): string {
  return line.product.pricingUnit === 'kilogram' ? `${line.quantity.toFixed(1)} kg` : String(Math.trunc(line.quantity));
}

/** Ports `GroceryCartLine.toJson`. */
export function groceryCartLineToJson(line: GroceryCartLine): Record<string, unknown> {
  return { product: groceryProductToJson(line.product), quantity: line.quantity };
}

/** Ports `GroceryCartLine.fromJson`, including its validation: throws when `quantity` is not finite and positive (mirrors the Dart `FormatException`). */
export function groceryCartLineFromJson(json: Record<string, unknown>): GroceryCartLine {
  const rawQuantity = json.quantity;
  const quantity = typeof rawQuantity === 'number' ? rawQuantity : Number(rawQuantity);
  if (!Number.isFinite(quantity) || quantity <= 0) {
    throw new Error('Invalid grocery cart line quantity');
  }

  return {
    product: groceryProductFromJson(json.product as Record<string, unknown>),
    quantity,
  };
}

/** Rounds to the nearest 1/100th -- ports `GroceryCart._normalizeQuantity`. */
function normalizeGroceryQuantity(quantity: number): number {
  return Math.round(quantity * 100) / 100;
}

// --- Cart store --------------------------------------------------------------

/** Ports `GroceryAddResult`. */
export type GroceryAddResult = 'added' | 'quantityIncreased' | 'unavailable' | 'storeConflict' | 'stockLimitReached';

/** The `service_pricing.service_id` every `GroceryStoreType` reads its delivery-fee estimate from -- `place_grocery_order` always reads `service_id = 'grocery'` regardless of store type, so this does not vary by store type either. Mirrors `GroceryController.serviceId`. */
export const GROCERY_SERVICE_ID = 'grocery' as const;

export interface AddGroceryProductOptions {
  /** Mirrors `addProduct`'s `replaceStoreCart` parameter. */
  replaceStoreCart?: boolean;
  /** Number of quantity steps (one item, or 0.5 kg per step) to add. Mirrors `addProduct`'s `steps` parameter. */
  steps?: number;
}

export interface GroceryCartState {
  lines: GroceryCartLine[];
  ownerId: string | null;
  isLoading: boolean;
  /** Ports `GroceryCart.loadForOwner` (the `onChanged` callback is this store's own `set`, so there is no separate parameter here). Returns `false` when superseded by a later call, mirroring the Dart return value. */
  loadForOwner: (ownerId: string | null) => Promise<boolean>;
  /** Ports `GroceryCart.addProduct`. Synchronous, like the Dart method -- persistence happens in the background (fire-and-forget), not awaited. */
  addProduct: (product: GroceryProduct, options?: AddGroceryProductOptions) => GroceryAddResult;
  /** Ports `GroceryCart.setQuantity`. */
  setQuantity: (productId: string, quantity: number) => boolean;
  /** Ports `GroceryCart.increment`. */
  increment: (productId: string) => boolean;
  /** Ports `GroceryCart.decrement`. */
  decrement: (productId: string) => boolean;
  /** Ports `GroceryCart.remove`. */
  remove: (productId: string) => boolean;
  /** Ports `GroceryCart.clearInMemory` -- test-only reset, does not persist. */
  clearInMemory: () => void;
  /** Ports `GroceryCart.clearAndPersist`. */
  clearAndPersist: () => Promise<void>;
}

export interface CreateGroceryCartStoreOptions {
  /** Defaults to a real `AsyncStorageCartStorage<GroceryCartLine>`, keyed per `storeType` -- see `groceryCartKeyPrefixFor`. */
  storage?: CartStorage<GroceryCartLine>;
  /** Defaults to the shared `sessionResetRegistry` singleton -- pass a fresh one in a test to avoid sharing state with other tests/modules. */
  registry?: SessionResetRegistry;
}

export interface GroceryCartStoreHandle {
  storeType: GroceryStoreType;
  store: UseBoundStore<StoreApi<GroceryCartState>>;
  /** Resolves once every cart write queued so far has been persisted. Exposed mainly for tests. */
  pendingWrite: () => Promise<void>;
  /** Stops listening for account changes. Mainly for tests -- the app-wide singletons below live for the app's lifetime. */
  unregister: () => void;
}

/** Mirrors `AppServices._buildGroceryController`'s per-`GroceryStoreType` key: grocery keeps its original key, Fresh Meat/Electronics get a `.{dbValue}` suffix. */
export function groceryCartKeyPrefixFor(storeType: GroceryStoreType): string {
  return storeType === 'grocery' ? 'zivo.cart.v1.grocery' : `zivo.cart.v1.grocery.${storeType}`;
}

function labelFor(storeType: GroceryStoreType): string {
  return `GroceryCartStore(${storeType})`;
}

/**
 * Builds an independent grocery cart store for `storeType`, wired to
 * `options.storage`/`options.registry` (real `AsyncStorage`/the shared
 * registry by default). Exists mainly so a test can build an isolated
 * instance instead of sharing one of the three app-wide singletons -- see
 * {@link useGroceryCartStore}/{@link useFreshMeatCartStore}/
 * {@link useElectronicsCartStore} for the ones the app actually renders
 * against.
 */
export function createGroceryCartStore(
  storeType: GroceryStoreType,
  options: CreateGroceryCartStoreOptions = {},
): GroceryCartStoreHandle {
  const storage =
    options.storage ??
    new AsyncStorageCartStorage<GroceryCartLine>({
      keyPrefix: groceryCartKeyPrefixFor(storeType),
      toJson: groceryCartLineToJson,
      fromJson: groceryCartLineFromJson,
    });
  const registry = options.registry ?? sessionResetRegistry;
  const writeQueue = new CartWriteQueue(labelFor(storeType));
  let loadGeneration = 0;

  function storageOwner(ownerId: string | null): string {
    return ownerId ?? GUEST_CART_OWNER;
  }

  function persist(): Promise<void> {
    const owner = storageOwner(store.getState().ownerId);
    const snapshot = store.getState().lines;
    return writeQueue.enqueue(() => storage.write(owner, snapshot));
  }

  const store = create<GroceryCartState>((set, get) => ({
    lines: [],
    ownerId: null,
    isLoading: false,

    loadForOwner: async (ownerId) => {
      const generation = ++loadGeneration;
      set({ ownerId, lines: [], isLoading: true });

      const loadedLines = await readCartLogged(storage, storageOwner(ownerId), labelFor(storeType));
      if (generation !== loadGeneration) {
        return false;
      }

      set({ lines: loadedLines, isLoading: false });
      // Warms (or refreshes) the delivery-fee estimate in the background;
      // never throws -- mirrors `GroceryController._loadPricing`.
      void ServicePricingRepository.load(GROCERY_SERVICE_ID);
      return true;
    },

    addProduct: (product, addOptions = {}) => {
      const { replaceStoreCart = false, steps = 1 } = addOptions;
      if (!isGroceryProductAvailable(product)) {
        return 'unavailable';
      }

      let lines = get().lines;
      const currentStoreId = lines.length === 0 ? null : lines[0].product.storeId;

      if (lines.length > 0 && currentStoreId !== product.storeId && !replaceStoreCart) {
        return 'storeConflict';
      }
      if (replaceStoreCart && currentStoreId !== product.storeId) {
        lines = [];
      }

      const index = lines.findIndex((line) => line.product.id === product.id);
      const existing = index === -1 ? undefined : lines[index];
      const step = groceryQuantityStep(product.pricingUnit);
      const nextQuantity = (existing?.quantity ?? 0) + step * steps;
      if (nextQuantity > product.availableQuantity) {
        return 'stockLimitReached';
      }

      const newLine: GroceryCartLine = { product, quantity: normalizeGroceryQuantity(nextQuantity) };
      const nextLines = index === -1 ? [...lines, newLine] : lines.map((line, i) => (i === index ? newLine : line));
      set({ lines: nextLines });
      void persist();
      return existing === undefined ? 'added' : 'quantityIncreased';
    },

    setQuantity: (productId, quantity) => {
      const lines = get().lines;
      const index = lines.findIndex((line) => line.product.id === productId);
      if (index === -1) {
        return false;
      }

      if (quantity <= 0) {
        set({ lines: lines.filter((_, i) => i !== index) });
        void persist();
        return true;
      }

      const product = lines[index].product;
      const step = groceryQuantityStep(product.pricingUnit);
      const steps = quantity / step;
      const isValidStep = Math.abs(steps - Math.round(steps)) < 0.0001;
      if (!isValidStep || quantity > product.availableQuantity) {
        return false;
      }

      const nextLines = lines.map((line, i) => (i === index ? { product, quantity: normalizeGroceryQuantity(quantity) } : line));
      set({ lines: nextLines });
      void persist();
      return true;
    },

    increment: (productId) => {
      const existing = get().lines.find((line) => line.product.id === productId);
      if (existing === undefined) {
        return false;
      }
      return get().setQuantity(productId, existing.quantity + groceryQuantityStep(existing.product.pricingUnit));
    },

    decrement: (productId) => {
      const existing = get().lines.find((line) => line.product.id === productId);
      if (existing === undefined) {
        return false;
      }
      return get().setQuantity(productId, existing.quantity - groceryQuantityStep(existing.product.pricingUnit));
    },

    remove: (productId) => {
      const lines = get().lines;
      const nextLines = lines.filter((line) => line.product.id !== productId);
      const removed = nextLines.length !== lines.length;
      if (removed) {
        set({ lines: nextLines });
        void persist();
      }
      return removed;
    },

    clearInMemory: () => {
      set({ lines: [] });
    },

    clearAndPersist: () => {
      set({ lines: [] });
      return persist();
    },
  }));

  const unregister = registry.register((nextOwnerId) => {
    void store.getState().loadForOwner(nextOwnerId);
  });

  return {
    storeType,
    store,
    pendingWrite: () => writeQueue.pending,
    unregister,
  };
}

const defaultGroceryCartStores: Record<GroceryStoreType, GroceryCartStoreHandle> = {
  grocery: createGroceryCartStore('grocery'),
  fresh_meat: createGroceryCartStore('fresh_meat'),
  electronics: createGroceryCartStore('electronics'),
};

/** The app-wide Grocery (`GroceryStoreType.grocery`) cart store. */
export const useGroceryCartStore = defaultGroceryCartStores.grocery.store;
/** The app-wide Fresh Meat cart store -- a separate cart from {@link useGroceryCartStore}, see this file's top comment. */
export const useFreshMeatCartStore = defaultGroceryCartStores.fresh_meat.store;
/** The app-wide Electronics cart store -- a separate cart from {@link useGroceryCartStore}, see this file's top comment. */
export const useElectronicsCartStore = defaultGroceryCartStores.electronics.store;

/** Looks up the app-wide store/handle for `storeType` dynamically (e.g. from a route param) instead of a static import of one of the three hooks above. */
export function groceryCartStoreFor(storeType: GroceryStoreType): GroceryCartStoreHandle {
  return defaultGroceryCartStores[storeType];
}

/** Exposed for the rare direct (non-React) caller and for tests -- most code should just read one of the three hooks above, or {@link groceryCartStoreFor}. */
export const groceryCartStores = defaultGroceryCartStores;

// --- Derived totals ----------------------------------------------------------
//
// Ports `GroceryController`'s cart-facing `subtotal`/`deliveryFee`/`total`
// getters (the pricing-aware pieces; `GroceryCart` itself only has
// `subtotal`) -- kept as pure functions for the same reason as
// `food-cart-store.ts`'s totals section.

export interface GroceryCartTotals {
  subtotal: number;
  itemCount: number;
  storeId: string | null;
  /** `null` until pricing has ever loaded -- an empty cart is always `0` regardless. Mirrors `GroceryController.deliveryFee`. Grocery charges no tax. */
  deliveryFee: number | null;
  /** `null` if `deliveryFee` is `null`. Mirrors `GroceryController.total`. */
  total: number | null;
}

/** Ports `GroceryCart.subtotal`. */
export function selectGroceryCartSubtotal(lines: GroceryCartLine[]): number {
  return lines.reduce((sum, line) => sum + groceryCartLineTotal(line), 0);
}

/** Ports `GroceryCart.storeId`. */
export function selectGroceryCartStoreId(lines: GroceryCartLine[]): string | null {
  return lines.length === 0 ? null : lines[0].product.storeId;
}

/** Combines `lines` with `pricing` (the last loaded `ServicePricing` for `'grocery'`, or `undefined` if none has loaded yet) into the same shape `GroceryController`'s getters expose. */
export function computeGroceryCartTotals(lines: GroceryCartLine[], pricing: ServicePricing | undefined): GroceryCartTotals {
  const subtotal = selectGroceryCartSubtotal(lines);
  const itemCount = lines.length;
  const storeId = selectGroceryCartStoreId(lines);

  if (lines.length === 0) {
    return { subtotal: 0, itemCount: 0, storeId, deliveryFee: 0, total: 0 };
  }

  const deliveryFee = pricing == null ? null : pricing.deliveryFeeCents;
  const total = deliveryFee == null ? null : subtotal + deliveryFee;
  return { subtotal, itemCount, storeId, deliveryFee, total };
}

/**
 * The hook a grocery/Fresh Meat/Electronics cart/checkout screen uses to
 * read live totals for `storeType` -- see {@link useFoodCartTotals}'s doc
 * comment in `food-cart-store.ts` for why this reads `service_pricing`
 * through `useServicePricing` instead of a one-off query.
 */
export function useGroceryCartTotals(storeType: GroceryStoreType): GroceryCartTotals {
  const handle = groceryCartStoreFor(storeType);
  const lines = handle.store((state) => state.lines);
  const pricingQuery = useServicePricing(GROCERY_SERVICE_ID);
  const pricing = pricingQuery.data ?? ServicePricingRepository.peek(GROCERY_SERVICE_ID);
  return computeGroceryCartTotals(lines, pricing);
}
