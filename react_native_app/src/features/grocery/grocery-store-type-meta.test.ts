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
import type { GroceryStoreType } from '@/stores/grocery-cart-store';
import { forId, forSlug, ServiceThemes } from '@/theme/service-theme';
import { GROCERY_STORE_TYPE_META } from './grocery-store-type-meta';

const GROCERY_STORE_TYPES = Object.keys(GROCERY_STORE_TYPE_META) as GroceryStoreType[];

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

  it('builds a URL-encoded product details route per store type (issue #390)', () => {
    expect(GROCERY_STORE_TYPE_META.grocery.productDetailsRoute('bakaal fresh', 'p 1')).toBe('/grocery/stores/bakaal%20fresh/product/p%201');
    expect(GROCERY_STORE_TYPE_META.fresh_meat.productDetailsRoute('butcher', 'goat')).toBe('/grocery/fresh-meat/stores/butcher/product/goat');
    expect(GROCERY_STORE_TYPE_META.electronics.productDetailsRoute('phones', 'p1')).toBe('/grocery/electronics/stores/phones/product/p1');
  });

  it('gives Fresh Meat and Electronics their own palette slug, distinct from plain grocery', () => {
    expect(GROCERY_STORE_TYPE_META.grocery.slug).toBeUndefined();
    expect(GROCERY_STORE_TYPE_META.fresh_meat.slug).toBe('fresh-meat');
    expect(GROCERY_STORE_TYPE_META.electronics.slug).toBe('electronics');
  });

  // Matches grocery_store_type_test.dart's "every category has its own
  // registered list, store, cart and checkout routes" (issue #393). Route
  // registration itself is checked in src/route-reachability.test.tsx.
  it('gives every store type its own list, store, cart and checkout routes, with no duplicates', () => {
    const paths = new Set<string>();
    for (const type of GROCERY_STORE_TYPES) {
      const meta = GROCERY_STORE_TYPE_META[type];
      for (const path of [meta.listRoute, meta.storeDetailsRoute(':storeId'), meta.cartRoute, meta.checkoutRoute]) {
        expect(paths.has(path)).toBe(false);
        paths.add(path);
      }
    }
    expect(paths.size).toBe(GROCERY_STORE_TYPES.length * 4);
    expect(GROCERY_STORE_TYPE_META.fresh_meat.storeDetailsRoute('hamar meat')).toBe(
      `${AppRoutes.freshMeat}/stores/hamar%20meat`,
    );
  });

  // Matches grocery_store_type_test.dart's "Fresh Meat and Electronics have
  // their own palettes" (issue #393).
  it('resolves three distinct accents, and plain grocery uses ServiceThemes.grocery', () => {
    const paletteFor = (type: GroceryStoreType) => {
      const { slug } = GROCERY_STORE_TYPE_META[type];
      return slug ? forSlug(slug, 'grocery') : forId('grocery');
    };
    const accents = new Set(GROCERY_STORE_TYPES.map((type) => paletteFor(type).accent));
    expect(accents.size).toBe(3);
    expect(paletteFor('grocery')).toBe(ServiceThemes.grocery);
    expect(paletteFor('fresh_meat')).toBe(ServiceThemes.freshMeat);
    expect(paletteFor('electronics')).toBe(ServiceThemes.electronics);
  });
});
