/**
 * Ports `flutter_app/lib/platform/activity/data/order_again_repository.dart`
 * (`ReorderBasket` and its three subtypes, `SupabaseOrderAgainRepository`)
 * -- issue #397 / P8-01.
 *
 * A past order's lines matched against today's catalog, ready to put back
 * into the right cart. Prices are today's, not the ones paid then.
 */
import { groceryProductFromRow, groceryStoreTypeFromDb, type GroceryProductRow } from '@/features/grocery/api/grocery-store';
import { supabase } from '@/platform/supabase/client';
import type { CartItem } from '@/stores/food-cart-store';
import { isGroceryProductAvailable, type GroceryProduct, type GroceryStoreType } from '@/stores/grocery-cart-store';
import {
  isPharmacyProductAvailable,
  isPharmacyProductOverTheCounter,
  type PharmacyProduct,
  type PharmacySaleType,
} from '@/stores/pharmacy-cart-store';
import type { ServiceId } from '@/theme/service-theme';

interface ReorderBasketBase {
  /** Items from the past order that can't be ordered any more (removed, out of stock, or the store is closed). */
  skippedNames: string[];
}

export interface FoodReorderBasket extends ReorderBasketBase {
  kind: 'food';
  /** Each `CartItem` carries its quantity. */
  items: CartItem[];
}

export interface GroceryReorderBasket extends ReorderBasketBase {
  kind: 'grocery';
  /** Grocery, Fresh Meat or Electronics: picks which cart to fill. */
  storeType: GroceryStoreType;
  /** Quantities are already capped at today's available stock. */
  lines: { product: GroceryProduct; quantity: number }[];
}

export interface PharmacyReorderBasket extends ReorderBasketBase {
  kind: 'pharmacy';
  /** Quantities are already capped at today's stock. */
  lines: { product: PharmacyProduct; quantity: number }[];
}

/** Ports the sealed `ReorderBasket` as a discriminated union. */
export type ReorderBasket = FoodReorderBasket | GroceryReorderBasket | PharmacyReorderBasket;

/** Ports `ReorderBasket.isEmpty`. */
export function isReorderBasketEmpty(basket: ReorderBasket): boolean {
  return basket.kind === 'food' ? basket.items.length === 0 : basket.lines.length === 0;
}

/** Ports `OrderAgainRepository`. */
export interface OrderAgainRepository {
  /** Loads `orderId`'s lines (the caller's own order -- RLS scopes it) and matches them against today's catalog. `null` when the order can't be found. */
  loadBasket(options: { serviceId: ServiceId; orderId: string }): Promise<ReorderBasket | null>;
}

type Row = Record<string, unknown>;
type QueryResult<T> = PromiseLike<{ data: T | null; error: { message: string } | null }>;

interface OrderAgainFilterBuilder extends QueryResult<Row[]> {
  eq(column: string, value: string | boolean): OrderAgainFilterBuilder;
  in(column: string, values: string[]): OrderAgainFilterBuilder;
  maybeSingle(): QueryResult<Row>;
}

/** The slice of `supabase` this repository depends on -- satisfied structurally by `src/test-utils/fake-supabase-client.ts`. */
export interface OrderAgainSource {
  from(table: string): { select(columns: string): OrderAgainFilterBuilder };
}

function rows(value: unknown): Row[] {
  return Array.isArray(value) ? value.filter((row): row is Row => row != null && typeof row === 'object') : [];
}

async function unwrap<T>(query: QueryResult<T>): Promise<T | null> {
  const { data, error } = await query;
  if (error) throw error;
  return data;
}

function idsOf(lines: Row[], key: string): string[] {
  return lines.map((line) => line[key]).filter((id): id is string => typeof id === 'string');
}

const PHARMACY_SALE_TYPES: Record<string, PharmacySaleType> = {
  otc: 'overTheCounter',
  prescription_only: 'prescriptionOnly',
  regulated: 'regulated',
};

function requiredString(row: Row, key: string): string {
  const value = row[key]?.toString().trim();
  if (!value) throw new Error(`Missing required pharmacy field: ${key}`);
  return value;
}

function requiredInt(row: Row, key: string): number {
  const value = row[key];
  const parsed = typeof value === 'number' ? value : parseInt(String(value ?? ''), 10);
  if (!Number.isInteger(parsed)) throw new Error(`Invalid pharmacy integer: ${key}`);
  return parsed;
}

/**
 * Ports `PharmacyProduct.fromMap` (the Supabase row shape: DB `sale_type`
 * values like `otc`, a joined `pharmacy_categories` object) -- distinct from
 * `pharmacyProductFromJson`, which reads the cart-persistence snapshot.
 */
export function pharmacyProductFromRow(row: Row): PharmacyProduct {
  const rawSaleType = requiredString(row, 'sale_type');
  const saleType = PHARMACY_SALE_TYPES[rawSaleType];
  if (saleType === undefined) throw new Error(`Unsupported pharmacy sale type: ${rawSaleType}`);
  const stockQuantity = requiredInt(row, 'stock_quantity');
  const unitPrice = requiredInt(row, 'unit_price');
  if (stockQuantity < 0 || unitPrice < 0) throw new Error('Pharmacy stock and price cannot be negative.');

  const rawCategory = Array.isArray(row.pharmacy_categories) ? row.pharmacy_categories[0] : row.pharmacy_categories;
  const category = rawCategory != null && typeof rawCategory === 'object' ? requiredString(rawCategory as Row, 'name') : requiredString(row, 'category_name');
  const imageUrl = row.image_url?.toString().trim();

  return {
    id: requiredString(row, 'id'),
    storeId: requiredString(row, 'store_id'),
    name: requiredString(row, 'name'),
    description: row.description?.toString().trim() ?? '',
    category,
    unitPrice,
    stockQuantity,
    saleType,
    imageUrl: imageUrl ? imageUrl : null,
  };
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

/** Ports `SupabaseOrderAgainRepository`. */
export class SupabaseOrderAgainRepository implements OrderAgainRepository {
  constructor(private readonly client: OrderAgainSource = supabase as unknown as OrderAgainSource) {}

  loadBasket({ serviceId, orderId }: { serviceId: ServiceId; orderId: string }): Promise<ReorderBasket | null> {
    switch (serviceId) {
      case 'food':
        return this.foodBasket(orderId);
      case 'grocery':
        return this.groceryBasket(orderId);
      case 'pharmacy':
        return this.pharmacyBasket(orderId);
      default:
        return Promise.resolve(null);
    }
  }

  private async foodBasket(orderId: string): Promise<FoodReorderBasket | null> {
    const order = await unwrap(
      this.client
        .from('food_orders')
        .select('restaurant_id, restaurant_name, food_order_items(menu_item_id, item_name, quantity)')
        .eq('id', orderId)
        .maybeSingle(),
    );
    if (order == null) return null;

    const pastLines = rows(order.food_order_items);
    const ids = idsOf(pastLines, 'menu_item_id');
    const menuRows =
      ids.length === 0
        ? []
        : rows(
            await unwrap(
              this.client.from('menu_items').select('id, name, price, image_url, restaurant_id').in('id', ids).eq('is_available', true),
            ),
          );
    const menuById = new Map(menuRows.map((row) => [String(row.id), row]));
    const restaurantOpen = await unwrap(
      this.client.from('restaurants').select('id').eq('id', String(order.restaurant_id)).eq('is_open', true).maybeSingle(),
    );

    const items: CartItem[] = [];
    const skippedNames: string[] = [];
    for (const line of pastLines) {
      const menuRow = line.menu_item_id == null ? undefined : menuById.get(String(line.menu_item_id));
      const price = menuRow?.price;
      if (restaurantOpen == null || menuRow == null || typeof price !== 'number') {
        skippedNames.push(String(line.item_name));
        continue;
      }
      items.push({
        menuItemId: String(menuRow.id),
        restaurantId: String(order.restaurant_id),
        restaurantName: String(order.restaurant_name),
        name: String(menuRow.name),
        unitPrice: Math.round(price),
        imageUrl: menuRow.image_url == null ? '' : String(menuRow.image_url),
        quantity: clamp(Math.trunc(Number(line.quantity)), 1, 99),
      });
    }
    return { kind: 'food', items, skippedNames };
  }

  private async groceryBasket(orderId: string): Promise<GroceryReorderBasket | null> {
    const order = await unwrap(
      this.client
        .from('grocery_orders')
        .select('store_id, grocery_order_items(product_id, product_name, quantity)')
        .eq('id', orderId)
        .maybeSingle(),
    );
    if (order == null) return null;

    const pastLines = rows(order.grocery_order_items);
    const ids = idsOf(pastLines, 'product_id');
    const productRows =
      ids.length === 0
        ? []
        : rows(
            await unwrap(
              this.client
                .from('grocery_products')
                .select(
                  'id, store_id, name, description, unit_price, pricing_unit, quantity_step, available_quantity, low_stock_threshold, icon, image_url, grocery_categories(name, sort_order)',
                )
                .in('id', ids)
                .eq('is_active', true),
            ),
          );
    const storeActive = await unwrap(
      this.client.from('grocery_stores').select('id, store_type').eq('id', String(order.store_id)).eq('is_active', true).maybeSingle(),
    );
    const productsById = new Map<string, GroceryProduct>();
    for (const row of productRows) {
      const product = groceryProductFromRow(row as unknown as GroceryProductRow);
      productsById.set(product.id, product);
    }

    const lines: GroceryReorderBasket['lines'] = [];
    const skippedNames: string[] = [];
    for (const line of pastLines) {
      const product = line.product_id == null ? undefined : productsById.get(String(line.product_id));
      if (storeActive == null || product == null || !isGroceryProductAvailable(product)) {
        skippedNames.push(String(line.product_name));
        continue;
      }
      const wanted = Number(line.quantity);
      lines.push({ product, quantity: wanted > product.availableQuantity ? product.availableQuantity : wanted });
    }
    return { kind: 'grocery', lines, skippedNames, storeType: groceryStoreTypeFromDb(storeActive?.store_type) };
  }

  private async pharmacyBasket(orderId: string): Promise<PharmacyReorderBasket | null> {
    const order = await unwrap(
      this.client.from('pharmacy_orders').select('pharmacy_order_items(product_id, product_name, quantity)').eq('id', orderId).maybeSingle(),
    );
    if (order == null) return null;

    const pastLines = rows(order.pharmacy_order_items);
    const ids = idsOf(pastLines, 'product_id');
    const productRows =
      ids.length === 0
        ? []
        : rows(
            await unwrap(
              this.client
                .from('pharmacy_products')
                .select('id, name, description, unit_price, stock_quantity, sale_type, image_url, store_id, pharmacy_categories!inner(id, name)')
                .in('id', ids)
                .eq('is_active', true)
                .eq('sale_type', 'otc'),
            ),
          );
    const productsById = new Map<string, PharmacyProduct>();
    for (const row of productRows) {
      const product = pharmacyProductFromRow(row);
      productsById.set(product.id, product);
    }

    const lines: PharmacyReorderBasket['lines'] = [];
    const skippedNames: string[] = [];
    for (const line of pastLines) {
      const product = line.product_id == null ? undefined : productsById.get(String(line.product_id));
      if (product == null || !isPharmacyProductOverTheCounter(product) || !isPharmacyProductAvailable(product)) {
        skippedNames.push(String(line.product_name));
        continue;
      }
      lines.push({ product, quantity: clamp(Math.trunc(Number(line.quantity)), 1, product.stockQuantity) });
    }
    return { kind: 'pharmacy', lines, skippedNames };
  }
}
