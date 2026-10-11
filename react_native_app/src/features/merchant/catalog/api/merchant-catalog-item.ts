/**
 * Ports `flutter_app/lib/features/merchant/catalog/models/merchant_catalog_item.dart`
 * (issue #410 / P9-05): one row from whichever catalog-item table a
 * merchant's vertical maps to (`menu_items` / `grocery_products` /
 * `pharmacy_products`). Fields that only exist on some verticals' tables are
 * `null` on the others -- see `store/api/merchant-vertical.ts` for the exact
 * column mapping.
 */
import { MERCHANT_VERTICAL_CONFIG, type MerchantVertical } from '../../store/api/merchant-vertical';

/**
 * Pricing unit for a grocery product -- mirrors `grocery_products.pricing_unit`'s
 * check constraint (`'each'` or `'kilogram'`).
 */
export type GroceryPricingUnit = 'each' | 'kilogram';

/** Mirrors `GroceryPricingUnit.values`. */
export const GROCERY_PRICING_UNITS: readonly GroceryPricingUnit[] = ['each', 'kilogram'];

/** Mirrors `GroceryPricingUnit.label`. */
export const GROCERY_PRICING_UNIT_LABEL: Readonly<Record<GroceryPricingUnit, string>> = {
  each: 'Each',
  kilogram: 'Per kilogram',
};

/**
 * Mirrors `GroceryPricingUnit.requiredQuantityStep`: the `quantity_step` the
 * table's check constraint ties to each pricing unit (1 for `each`, 0.5 for
 * `kilogram`).
 */
export const GROCERY_REQUIRED_QUANTITY_STEP: Readonly<Record<GroceryPricingUnit, number>> = {
  each: 1,
  kilogram: 0.5,
};

/** Mirrors `GroceryPricingUnit.fromColumnValue`: anything but `'kilogram'` is `'each'`. */
export function groceryPricingUnitFromColumn(value: unknown): GroceryPricingUnit {
  return value === 'kilogram' ? 'kilogram' : 'each';
}

export interface MerchantCatalogItem {
  /** `''` on a not-yet-created draft. */
  id: string;
  storeId: string;
  vertical: MerchantVertical;
  name: string;
  description: string | null;
  /** Integer cents in every vertical (`menu_items.price` / `*.unit_price`). */
  priceCents: number;
  isAvailable: boolean;
  /** `image_url` on every vertical's item table. */
  imageUrl: string | null;
  /** `grocery_products.pricing_unit` only. */
  pricingUnit: GroceryPricingUnit | null;
  /** `grocery_products.available_quantity` only. */
  availableQuantity: number | null;
  /** `pharmacy_products.category_id` only (a required foreign key to `pharmacy_categories`). */
  categoryId: string | null;
  /** `pharmacy_products.stock_quantity` only. */
  stockQuantity: number | null;
}

/**
 * A `pharmacy_categories` row, for the required category picker when adding
 * or editing a pharmacy product.
 */
export interface PharmacyCategory {
  id: string;
  name: string;
}

function stringOrNull(value: unknown): string | null {
  return typeof value === 'string' ? value : null;
}

/** Accepts a JSON number or a numeric string (PostgREST returns `numeric` columns as strings). */
function numberOrNull(value: unknown): number | null {
  if (typeof value === 'number') return Number.isFinite(value) ? value : null;
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

/** Mirrors `MerchantCatalogItem.fromMap`. */
export function merchantCatalogItemFromRow(
  row: Record<string, unknown>,
  { vertical, storeId }: { vertical: MerchantVertical; storeId: string },
): MerchantCatalogItem {
  const config = MERCHANT_VERTICAL_CONFIG[vertical];
  const price = numberOrNull(row[config.itemPriceColumn]);
  const available = row[config.itemAvailableColumn];
  const stock = numberOrNull(row.stock_quantity);
  return {
    id: String(row.id),
    storeId,
    vertical,
    name: stringOrNull(row.name) ?? '',
    description: stringOrNull(row.description),
    priceCents: price == null ? 0 : Math.round(price),
    isAvailable: typeof available === 'boolean' ? available : false,
    imageUrl: stringOrNull(row.image_url),
    pricingUnit: vertical === 'grocery' ? groceryPricingUnitFromColumn(row.pricing_unit) : null,
    availableQuantity: vertical === 'grocery' ? numberOrNull(row.available_quantity) : null,
    categoryId: vertical === 'pharmacy' ? stringOrNull(row.category_id) : null,
    stockQuantity: vertical === 'pharmacy' && stock != null ? Math.round(stock) : null,
  };
}

/** Mirrors `PharmacyCategory.fromMap`. */
export function pharmacyCategoryFromRow(row: Record<string, unknown>): PharmacyCategory {
  return { id: String(row.id), name: stringOrNull(row.name) ?? '' };
}
