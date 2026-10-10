/**
 * Ports the Supabase-row mappers of
 * `flutter_app/lib/services/pharmacy/models/pharmacy_store.dart`
 * (`PharmacyStore`) and `.../models/pharmacy_product.dart`
 * (`PharmacyProduct.fromMap`, `PharmacyCategory`) -- issue #394 / P7-06.
 *
 * `PharmacyProduct` itself (and its cart-persistence `toJson`/`fromJson`)
 * already lives in `src/stores/pharmacy-cart-store.ts` (issue #376); this
 * file reuses that exact shape so a product fetched here can be handed
 * straight to the cart's `addProduct`, same as the Dart source's one shared
 * model. It only adds the raw-row mapping the cart store doesn't need.
 */
import type { PharmacyProduct, PharmacySaleType } from '@/stores/pharmacy-cart-store';

export type { PharmacyProduct, PharmacySaleType };

/** Ports `PharmacyStore`: a single pharmacy a customer can order OTC products from (`public.pharmacy_stores`). */
export interface PharmacyStore {
  id: string;
  name: string;
  address: string;
  /** Store photo (`pharmacy_stores.image_url`). `null` means no photo. */
  imageUrl: string | null;
}

/** Ports `PharmacyCategory`. */
export interface PharmacyCategory {
  id: string;
  name: string;
}

/** Raw `pharmacy_stores` row shape this module queries. */
export interface PharmacyStoreRow {
  id: unknown;
  name: unknown;
  address?: unknown;
  image_url?: unknown;
}

type CategoryEmbed = { id?: unknown; name?: unknown };

/** Raw `pharmacy_products` row shape this module queries. */
export interface PharmacyProductRow {
  id: unknown;
  store_id: unknown;
  name: unknown;
  description?: unknown;
  unit_price: unknown;
  stock_quantity: unknown;
  sale_type: unknown;
  image_url?: unknown;
  category_name?: unknown;
  pharmacy_categories?: CategoryEmbed | CategoryEmbed[] | null;
}

/** Raw `pharmacy_categories` row shape this module queries. */
export interface PharmacyCategoryRow {
  id: unknown;
  name: unknown;
}

function asTrimmedString(value: unknown): string | null {
  return value == null ? null : String(value).trim();
}

/** Mirrors `_requiredString`: throws on a missing/blank value. */
function requiredString(row: object, key: string, kind: string): string {
  const value = asTrimmedString((row as Record<string, unknown>)[key]);
  if (value == null || value.length === 0) {
    throw new Error(`Missing required ${kind} field: ${key}`);
  }
  return value;
}

/** Mirrors `_optionalString`: a missing value becomes `''`. */
function optionalString(row: object, key: string): string {
  return asTrimmedString((row as Record<string, unknown>)[key]) ?? '';
}

/** Mirrors `_optionalNullableString`/`_nullIfBlank`: a missing or blank value becomes `null`. */
function nullIfBlank(value: unknown): string | null {
  const trimmed = asTrimmedString(value) ?? '';
  return trimmed.length === 0 ? null : trimmed;
}

/** Mirrors `_requiredInt`: accepts an integer or an integer-looking string, throws otherwise. */
function requiredInt(row: object, key: string): number {
  const value = (row as Record<string, unknown>)[key];
  const parsed =
    typeof value === 'number' && Number.isInteger(value)
      ? value
      : /^-?\d+$/.test(String(value ?? '').trim())
        ? parseInt(String(value).trim(), 10)
        : NaN;
  if (!Number.isFinite(parsed)) {
    throw new Error(`Invalid pharmacy integer: ${key}`);
  }
  return parsed;
}

/** Ports `PharmacyStore.fromMap`. */
export function pharmacyStoreFromRow(row: PharmacyStoreRow): PharmacyStore {
  return {
    id: requiredString(row, 'id', 'pharmacy store'),
    name: requiredString(row, 'name', 'pharmacy store'),
    address: optionalString(row, 'address'),
    imageUrl: nullIfBlank(row.image_url),
  };
}

/** Ports `PharmacyProduct.fromMap`'s `sale_type` switch. */
function saleTypeFromDb(value: string): PharmacySaleType {
  switch (value) {
    case 'otc':
      return 'overTheCounter';
    case 'prescription_only':
      return 'prescriptionOnly';
    case 'regulated':
      return 'regulated';
    default:
      throw new Error(`Unsupported pharmacy sale type: ${value}`);
  }
}

/**
 * Ports `PharmacyProduct.fromMap`, including its validation: an unknown
 * `sale_type` or a negative stock/price throws. The category name comes
 * from the embedded `pharmacy_categories` row when present, otherwise from
 * a flat `category_name` column.
 */
export function pharmacyProductFromRow(row: PharmacyProductRow): PharmacyProduct {
  const saleType = saleTypeFromDb(requiredString(row, 'sale_type', 'pharmacy'));
  const stockQuantity = requiredInt(row, 'stock_quantity');
  const unitPrice = requiredInt(row, 'unit_price');
  if (stockQuantity < 0 || unitPrice < 0) {
    throw new Error('Pharmacy stock and price cannot be negative.');
  }

  const embed = Array.isArray(row.pharmacy_categories) ? row.pharmacy_categories[0] : row.pharmacy_categories;
  const category =
    embed != null && typeof embed === 'object'
      ? requiredString(embed, 'name', 'pharmacy')
      : requiredString(row, 'category_name', 'pharmacy');

  return {
    id: requiredString(row, 'id', 'pharmacy'),
    storeId: requiredString(row, 'store_id', 'pharmacy'),
    name: requiredString(row, 'name', 'pharmacy'),
    description: optionalString(row, 'description'),
    category,
    unitPrice,
    stockQuantity,
    saleType,
    imageUrl: nullIfBlank(row.image_url),
  };
}

/** Ports `PharmacyCategory.fromMap`. */
export function pharmacyCategoryFromRow(row: PharmacyCategoryRow): PharmacyCategory {
  return {
    id: requiredString(row, 'id', 'pharmacy'),
    name: requiredString(row, 'name', 'pharmacy'),
  };
}
