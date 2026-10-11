/**
 * Ports `flutter_app/lib/features/merchant/store/models/merchant_vertical.dart`
 * (issue #407 / P9-02): the three service verticals a merchant store can
 * belong to, and each one's per-table column mapping.
 *
 * The three store tables do not share one shape (`grocery_stores` uses
 * `area` instead of `address` and `is_active` instead of `is_open`; only
 * `restaurants` has `description`; the food photo column is `logo_url`, not
 * the stale `schema.sql`'s `image_url`). Rather than force a fictitious
 * common shape onto the client, each vertical's per-column behavior is
 * captured here and the UI adapts to what a vertical actually supports.
 *
 * The Dart enum + extension becomes a string union plus a config record.
 * Only the store-table half is ported here; the catalog-item columns
 * (`itemTable`, `itemPriceColumn`, ...) land with the catalog screen.
 */
export type MerchantVertical = 'food' | 'grocery' | 'pharmacy';

/** Mirrors `MerchantVertical.values` -- also the lookup order `fetchOwnStore` uses. */
export const MERCHANT_VERTICALS: readonly MerchantVertical[] = ['food', 'grocery', 'pharmacy'];

export interface MerchantVerticalConfig {
  displayName: string;
  /** The store table for this vertical. */
  storeTable: 'restaurants' | 'grocery_stores' | 'pharmacy_stores';
  /** The open/closed boolean column on {@link storeTable}. */
  storeActiveColumn: 'is_open' | 'is_active';
  /** The free-text location column on {@link storeTable} (`grocery_stores` calls it `area`). */
  storeLocationColumn: 'address' | 'area';
  storeLocationLabel: string;
  /** Only `restaurants` has a `description` column. */
  storeSupportsDescription: boolean;
  /** `restaurants.logo_url` / `grocery_stores.image_url` / `pharmacy_stores.image_url`. */
  storeImageColumn: 'logo_url' | 'image_url';
  /** `restaurants.id` is a server-generated `uuid`; the other two are client-supplied `text` keys. */
  storeIdIsServerGenerated: boolean;
}

export const MERCHANT_VERTICAL_CONFIG: Readonly<Record<MerchantVertical, MerchantVerticalConfig>> = {
  food: {
    displayName: 'Food',
    storeTable: 'restaurants',
    storeActiveColumn: 'is_open',
    storeLocationColumn: 'address',
    storeLocationLabel: 'Address',
    storeSupportsDescription: true,
    storeImageColumn: 'logo_url',
    storeIdIsServerGenerated: true,
  },
  grocery: {
    displayName: 'Grocery',
    storeTable: 'grocery_stores',
    storeActiveColumn: 'is_active',
    storeLocationColumn: 'area',
    storeLocationLabel: 'Area',
    storeSupportsDescription: false,
    storeImageColumn: 'image_url',
    storeIdIsServerGenerated: false,
  },
  pharmacy: {
    displayName: 'Pharmacy',
    storeTable: 'pharmacy_stores',
    storeActiveColumn: 'is_active',
    storeLocationColumn: 'address',
    storeLocationLabel: 'Address',
    storeSupportsDescription: false,
    storeImageColumn: 'image_url',
    storeIdIsServerGenerated: false,
  },
};
