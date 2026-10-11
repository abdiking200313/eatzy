/**
 * Ports `flutter_app/lib/features/merchant/store/models/merchant_store.dart`
 * (issue #407 / P9-02): the signed-in merchant's own store row, from
 * whichever vertical table it actually lives in. See `merchant-vertical.ts`
 * for the per-vertical column mapping this is built from.
 */
import { MERCHANT_VERTICAL_CONFIG, type MerchantVertical } from './merchant-vertical';

export interface MerchantStore {
  id: string;
  vertical: MerchantVertical;
  name: string;
  /** `restaurants.address` / `pharmacy_stores.address` / `grocery_stores.area`. */
  location: string;
  /** `restaurants.is_open` / `grocery_stores.is_active` / `pharmacy_stores.is_active`. */
  isOpen: boolean;
  /** `restaurants.description`. `null` for grocery/pharmacy, which have no such column. */
  description: string | null;
  /** `restaurants.logo_url` / `grocery_stores.image_url` / `pharmacy_stores.image_url`. */
  imageUrl: string | null;
}

function stringOrNull(value: unknown): string | null {
  return typeof value === 'string' ? value : null;
}

/** Mirrors `MerchantStore.fromMap`. */
export function merchantStoreFromRow(row: Record<string, unknown>, vertical: MerchantVertical): MerchantStore {
  const config = MERCHANT_VERTICAL_CONFIG[vertical];
  return {
    id: String(row.id),
    vertical,
    name: stringOrNull(row.name) ?? '',
    location: stringOrNull(row[config.storeLocationColumn]) ?? '',
    isOpen: typeof row[config.storeActiveColumn] === 'boolean' ? (row[config.storeActiveColumn] as boolean) : false,
    description: config.storeSupportsDescription ? stringOrNull(row.description) : null,
    imageUrl: stringOrNull(row[config.storeImageColumn]),
  };
}
