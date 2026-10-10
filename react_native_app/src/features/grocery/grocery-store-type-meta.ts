/**
 * Ports the per-`GroceryStoreType` display/route metadata from
 * `flutter_app/lib/services/grocery/models/grocery_models.dart`'s
 * `GroceryStoreType` enum (issue #389 / P7-01) -- `title`/`serviceName`/
 * `storesNoun`/`listRoute`/`cartRoute`/`checkoutRoute`/`palette`.
 * `GroceryStoreType` itself (the `'grocery' | 'fresh_meat' | 'electronics'`
 * union) already lives in `src/stores/grocery-cart-store.ts` (issue #376).
 */
import { AppRoutes, electronicsStoreDetails, freshMeatStoreDetails, groceryStoreDetails } from '@/platform/navigation/app-routes';
import type { GroceryStoreType } from '@/stores/grocery-cart-store';
import type { ServiceSlug } from '@/theme/service-theme';

export interface GroceryStoreTypeMeta {
  /** Store-list title, e.g. "Groceries". Mirrors `GroceryStoreType.title`. */
  title: string;
  /** Used in cart/checkout titles, e.g. "Fresh Meat cart". Mirrors `GroceryStoreType.serviceName`. */
  serviceName: string;
  /** Plural noun used in empty-state copy, e.g. "No butchers found." Mirrors `GroceryStoreType.storesNoun`. */
  storesNoun: string;
  cartRoute: string;
  /** `useServiceTheme`'s `slug` param, so Fresh Meat/Electronics render their own accent instead of the shared grocery one. `undefined` for plain grocery. */
  slug?: ServiceSlug;
  storeDetailsRoute: (storeId: string) => string;
}

/** Mirrors `GroceryStoreType.values` -- used to build a store's details route from its own `store_type`. */
export const GROCERY_STORE_TYPE_META: Record<GroceryStoreType, GroceryStoreTypeMeta> = {
  grocery: {
    title: 'Groceries',
    serviceName: 'Grocery',
    storesNoun: 'grocery stores',
    cartRoute: AppRoutes.groceryCart,
    storeDetailsRoute: groceryStoreDetails,
  },
  fresh_meat: {
    title: 'Fresh Meat',
    serviceName: 'Fresh Meat',
    storesNoun: 'butchers',
    cartRoute: AppRoutes.freshMeatCart,
    slug: 'fresh-meat',
    storeDetailsRoute: freshMeatStoreDetails,
  },
  electronics: {
    title: 'Electronics',
    serviceName: 'Electronics',
    storesNoun: 'electronics stores',
    cartRoute: AppRoutes.electronicsCart,
    slug: 'electronics',
    storeDetailsRoute: electronicsStoreDetails,
  },
};
