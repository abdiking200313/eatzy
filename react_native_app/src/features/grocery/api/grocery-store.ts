/**
 * Ports the store-list-facing slice of
 * `flutter_app/lib/services/grocery/models/grocery_models.dart`'s
 * `GroceryStore`/`GroceryProduct.fromMap` (issue #389 / P7-01).
 *
 * `GroceryProduct`/`GroceryCartLine` themselves already exist in
 * `src/stores/grocery-cart-store.ts` (issue #376), narrowed to the fields
 * the cart needs. This file reuses that exact `GroceryProduct` shape (so a
 * product fetched here can be handed straight to `addProduct` later, same
 * as the Dart source's one shared model) and adds `groceryProductFromRow`,
 * the raw-Supabase-row mapper `grocery-cart-store.ts` doesn't need (it only
 * round-trips cart-persistence JSON via `groceryProductFromJson`).
 */
import type { GroceryPricingUnit, GroceryProduct, GroceryStockState, GroceryStoreType } from '@/stores/grocery-cart-store';

/** Raw `grocery_products` row shape this module queries. */
export interface GroceryProductRow {
  id: string;
  store_id: string;
  name: string;
  description: string | null;
  unit_price: number;
  pricing_unit: string;
  quantity_step: number;
  available_quantity: number;
  low_stock_threshold: number;
  icon: string | null;
  image_url: string | null;
  grocery_categories: { name: string | null; sort_order: number | null } | { name: string | null; sort_order: number | null }[] | null;
}

/** Raw `grocery_stores` row shape this module queries. */
export interface GroceryStoreRow {
  id: string;
  name: string;
  area: string;
  image_url: string | null;
  store_type: string;
}

/** Ports `GroceryStore` (the store-list-facing fields only). */
export interface GroceryStore {
  id: string;
  name: string;
  area: string;
  imageUrl: string | null;
  storeType: GroceryStoreType;
  products: GroceryProduct[];
}

/** Ports `GroceryStoreType.fromDb`: an unrecognized value falls back to `'grocery'` rather than hiding the store from every list. */
export function groceryStoreTypeFromDb(value: unknown): GroceryStoreType {
  return value === 'fresh_meat' || value === 'electronics' ? value : 'grocery';
}

/** Ports `GroceryProduct.fromMap`, including its `quantity_step` validation and the `stockState` derived from `available_quantity` vs. `low_stock_threshold`. */
export function groceryProductFromRow(row: GroceryProductRow): GroceryProduct {
  const pricingUnit = row.pricing_unit as GroceryPricingUnit;
  if (pricingUnit !== 'each' && pricingUnit !== 'kilogram') {
    throw new Error(`Unsupported grocery pricing unit: ${String(row.pricing_unit)}`);
  }

  const availableQuantity = Number(row.available_quantity);
  const lowStockThreshold = Number(row.low_stock_threshold);
  const quantityStep = Number(row.quantity_step);
  const expectedStep = pricingUnit === 'each' ? 1 : 0.5;
  if (quantityStep !== expectedStep) {
    throw new Error(`Invalid quantity_step for ${pricingUnit}: ${quantityStep}`);
  }

  const stockState: GroceryStockState =
    availableQuantity <= 0 ? 'outOfStock' : availableQuantity <= lowStockThreshold ? 'lowStock' : 'inStock';

  const category = Array.isArray(row.grocery_categories) ? row.grocery_categories[0] : row.grocery_categories;

  return {
    id: row.id,
    storeId: row.store_id,
    name: row.name,
    description: row.description ?? '',
    unitPrice: Math.max(0, Math.round(Number(row.unit_price))),
    pricingUnit,
    stockState,
    availableQuantity,
    icon: row.icon && row.icon.length > 0 ? row.icon : '🛒',
    imageUrl: row.image_url,
    categoryName: category?.name ?? null,
    categorySortOrder: category?.sort_order ?? 0,
  };
}

/** Ports `GroceryStore.fromMap`. */
export function groceryStoreFromRow(row: GroceryStoreRow, products: GroceryProduct[]): GroceryStore {
  return {
    id: row.id,
    name: row.name,
    area: row.area,
    imageUrl: row.image_url,
    storeType: groceryStoreTypeFromDb(row.store_type),
    products,
  };
}
