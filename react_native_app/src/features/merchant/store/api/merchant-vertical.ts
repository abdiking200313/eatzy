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
 * The catalog-item columns (`itemTable`, `itemPriceColumn`, ...) were added
 * with the catalog screen (issue #410 / P9-05).
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
  /** The catalog-item table for this vertical. */
  itemTable: 'menu_items' | 'grocery_products' | 'pharmacy_products';
  /**
   * The foreign-key column on {@link itemTable} pointing at the store row --
   * the join the merchant RLS write policies use to scope item writes
   * ("ownership is inherited from the parent store").
   */
  itemStoreColumn: 'restaurant_id' | 'store_id';
  /** The integer-cents price column on {@link itemTable}. */
  itemPriceColumn: 'price' | 'unit_price';
  /** The availability boolean column on {@link itemTable}. */
  itemAvailableColumn: 'is_available' | 'is_active';
  /** `menu_items.id` is a server-generated `uuid`; `grocery_products.id` / `pharmacy_products.id` are client-supplied `text` keys. */
  itemIdIsServerGenerated: boolean;
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
    itemTable: 'menu_items',
    itemStoreColumn: 'restaurant_id',
    itemPriceColumn: 'price',
    itemAvailableColumn: 'is_available',
    itemIdIsServerGenerated: true,
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
    itemTable: 'grocery_products',
    itemStoreColumn: 'store_id',
    itemPriceColumn: 'unit_price',
    itemAvailableColumn: 'is_active',
    itemIdIsServerGenerated: false,
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
    itemTable: 'pharmacy_products',
    itemStoreColumn: 'store_id',
    itemPriceColumn: 'unit_price',
    itemAvailableColumn: 'is_active',
    itemIdIsServerGenerated: false,
  },
};
