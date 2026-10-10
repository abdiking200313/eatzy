/**
 * Ports the non-widget-test cases from
 * `flutter_app/test/grocery_store_type_test.dart` (issue #389 / P7-01):
 * every `GroceryStoreType` gets its own store-details/cart route and its
 * own palette slug. The routing-table/palette-registration tests
 * themselves (`AppRouter.hasRegisteredRoute`, `ServiceThemes.grocery`) have
 * no RN equivalent to port against -- Expo Router has no such registry,
 * and `ServiceThemes`'s own port is already covered by
 * `src/theme/service-theme.test.ts` -- so this checks the one thing this
 * file actually owns: every store type resolves to a distinct, correct
 * route/slug combination.
 */
import { AppRoutes } from '@/platform/navigation/app-routes';
import { GROCERY_STORE_TYPE_META } from './grocery-store-type-meta';

describe('GROCERY_STORE_TYPE_META', () => {
  it('gives every store type its own cart route', () => {
    const cartRoutes = new Set(Object.values(GROCERY_STORE_TYPE_META).map((meta) => meta.cartRoute));
    expect(cartRoutes).toEqual(new Set([AppRoutes.groceryCart, AppRoutes.freshMeatCart, AppRoutes.electronicsCart]));
  });

  it('builds a URL-encoded store details route per store type', () => {
    expect(GROCERY_STORE_TYPE_META.grocery.storeDetailsRoute('bakaal fresh')).toBe('/grocery/stores/bakaal%20fresh');
    expect(GROCERY_STORE_TYPE_META.fresh_meat.storeDetailsRoute('hamar meat')).toBe('/grocery/fresh-meat/stores/hamar%20meat');
    expect(GROCERY_STORE_TYPE_META.electronics.storeDetailsRoute('phone hub')).toBe('/grocery/electronics/stores/phone%20hub');
  });

  it('gives Fresh Meat and Electronics their own palette slug, distinct from plain grocery', () => {
    expect(GROCERY_STORE_TYPE_META.grocery.slug).toBeUndefined();
    expect(GROCERY_STORE_TYPE_META.fresh_meat.slug).toBe('fresh-meat');
    expect(GROCERY_STORE_TYPE_META.electronics.slug).toBe('electronics');
  });
});
