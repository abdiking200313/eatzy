/// <reference types="node" />
/**
 * Route-by-route parity guard for issue #415 (P10-03). Pairs with
 * `docs/parity-checklist.md`, which has one row per route in this table.
 *
 * `route-reachability.test.tsx` renders most routes to check they mount.
 * This file checks the route table itself against the Flutter source:
 *
 *  1. Every route constant in `flutter_app/lib/app/app_routes.dart` is in
 *     `FLUTTER_ROUTES` below, or in `NOT_A_ROUTE` with a reason. A route
 *     added on the Flutter side fails this test until it gets an RN row.
 *  2. Each row's RN file exists under `src/app/`, and its Expo Router URL is
 *     the same path as the Flutter route.
 *  3. Every file under `src/app/` is a row here or is listed in `RN_ONLY`.
 *  4. The "linked from somewhere" half of
 *     `flutter_app/test/route_reachability_test.dart`: each route has an
 *     in-app link (its `link` pattern matches some non-test source file), or
 *     is deep-link-only with a reason. As in Flutter, a deep-link-only route
 *     must really have no in-app link.
 *
 * Reads the Flutter file from the monorepo checkout. CI checks out the whole
 * repository (see `.github/workflows/react-native.yml`).
 */
import fs from 'fs';
import path from 'path';

const SRC_DIR = __dirname;
const APP_DIR = path.join(SRC_DIR, 'app');
const FLUTTER_ROUTES_FILE = path.resolve(SRC_DIR, '../../flutter_app/lib/app/app_routes.dart');

type RouteRow = {
  /** The `AppRoutes` constant name in app_routes.dart. */
  name: string;
  /** Route file, relative to `src/app/`. */
  rnFile: string;
  /** Evidence of an in-app link to this route, matched against RN source with comments removed. */
  link: RegExp;
  /** Set when the route intentionally has no in-app link. Mirrors Flutter's `_deepLinkOnlyRoutes`. */
  deepLinkOnly?: string;
  /** The route file is only a redirect (a router alias). Its own source does not count as a link. */
  redirect?: true;
  /**
   * Set when the RN app currently links to a route that Flutter keeps
   * deep-link-only. Names the follow-up issue. Remove it once fixed.
   */
  knownDivergence?: string;
};

// prettier-ignore
const FLUTTER_ROUTES: RouteRow[] = [
  // Public
  { name: 'root', rnFile: 'index.tsx', link: /router\.(?:replace|push|navigate)\(\s*'\/'\s*\)|href="\/"/, redirect: true,
    deepLinkOnly: 'index route, always redirected to welcome',
    knownDivergence: 'AppScaffold back fallback goes to "/" instead of "/app" (#540)' },
  { name: 'welcome', rnFile: '(auth)/welcome.tsx', link: /\bAppRoutes\.welcome(?:Revisit)?\b/ },
  { name: 'login', rnFile: '(auth)/login.tsx', link: /\bAppRoutes\.login\b/ },
  { name: 'register', rnFile: '(auth)/register.tsx', link: /\bAppRoutes\.register\b/ },
  { name: 'forgotPassword', rnFile: '(auth)/forgot-password.tsx', link: /\bAppRoutes\.forgotPassword\b/ },
  { name: 'resetPassword', rnFile: '(app)/reset-password.tsx', link: /\bAppRoutes\.resetPassword\b/ },

  // Bottom-nav tabs
  { name: 'mainApp', rnFile: '(app)/(tabs)/app.tsx', link: /\bAppRoutes\.mainApp\b/ },
  { name: 'explore', rnFile: '(app)/(tabs)/explore.tsx', link: /\bAppRoutes\.explore\b/ },
  { name: 'activity', rnFile: '(app)/(tabs)/activity.tsx', link: /\bAppRoutes\.activity\b/ },
  { name: 'profile', rnFile: '(app)/(tabs)/profile.tsx', link: /\bAppRoutes\.profile\b|'\/profile'/,
    deepLinkOnly: 'reachable as the Profile bottom-nav tab, not a route push' },

  // Standalone protected pages
  { name: 'services', rnFile: '(app)/services.tsx', link: /\bAppRoutes\.services\b/ },
  { name: 'addresses', rnFile: '(app)/addresses.tsx', link: /\bAppRoutes\.addresses\b|'\/addresses'/,
    deepLinkOnly: 'hidden while delivery addresses are out of scope (2026-09-25)' },
  { name: 'settings', rnFile: '(app)/settings/index.tsx', link: /\bAppRoutes\.settings\b/ },
  { name: 'support', rnFile: '(app)/support.tsx', link: /\bAppRoutes\.support\b/ },
  { name: 'privacyPolicy', rnFile: '(app)/settings/privacy-policy.tsx', link: /\bAppRoutes\.privacyPolicy\b/ },
  { name: 'termsOfService', rnFile: '(app)/settings/terms-of-service.tsx', link: /\bAppRoutes\.termsOfService\b/ },
  { name: 'trackOrder', rnFile: '(app)/track-order/index.tsx', link: /\bAppRoutes\.trackOrder\b|'\/track-order'/,
    deepLinkOnly: 'kept only for old deep links with no order id' },
  { name: 'trackOrderDetails', rnFile: '(app)/track-order/[serviceId]/[orderId].tsx', link: /\btrackOrderDetailsPath\(/ },

  // Merchant
  { name: 'merchantDashboard', rnFile: 'merchant/index.tsx', link: /\bAppRoutes\.merchantDashboard\b/ },
  { name: 'merchantOrderDetail', rnFile: 'merchant/orders/[orderId].tsx', link: /\bmerchantOrderDetailPath\(/ },
  { name: 'merchantCatalog', rnFile: 'merchant/catalog.tsx', link: /\bAppRoutes\.merchantCatalog\b/ },

  // Food
  { name: 'food', rnFile: '(app)/(tabs)/food/index.tsx', link: /\bAppRoutes\.food\b/ },
  { name: 'foodRestaurant', rnFile: '(app)/(tabs)/food/restaurants/[restaurantId]/index.tsx', link: /\brestaurantDetails\(/ },
  { name: 'foodMenuItem', rnFile: '(app)/(tabs)/food/restaurants/[restaurantId]/item/[itemId].tsx', link: /\bfoodMenuItemDetails\(/ },
  { name: 'foodCategories', rnFile: '(app)/(tabs)/food/categories.tsx', link: /\bAppRoutes\.foodCategories\b/ },
  { name: 'foodExplore', rnFile: '(app)/(tabs)/food/explore.tsx', link: /\bAppRoutes\.foodExplore\b|\bfoodExplorePath\(/ },
  { name: 'foodCart', rnFile: '(app)/(tabs)/food/cart.tsx', link: /\bAppRoutes\.foodCart\b/ },
  { name: 'foodCheckout', rnFile: '(app)/(tabs)/food/checkout.tsx', link: /\bAppRoutes\.foodCheckout\b/ },

  // Grocery engine: Grocery, Fresh Meat, Electronics
  { name: 'grocery', rnFile: '(app)/(tabs)/grocery/index.tsx', link: /\bAppRoutes\.grocery\b/ },
  { name: 'groceryStore', rnFile: '(app)/(tabs)/grocery/stores/[storeId]/index.tsx', link: /\bgroceryStoreDetails\b/ },
  { name: 'groceryProduct', rnFile: '(app)/(tabs)/grocery/stores/[storeId]/product/[productId].tsx', link: /\bgroceryProductDetails\b/ },
  { name: 'groceryCart', rnFile: '(app)/(tabs)/grocery/cart.tsx', link: /\bAppRoutes\.groceryCart\b/ },
  { name: 'groceryCheckout', rnFile: '(app)/(tabs)/grocery/checkout.tsx', link: /\bAppRoutes\.groceryCheckout\b/ },
  { name: 'freshMeat', rnFile: '(app)/(tabs)/grocery/fresh-meat/index.tsx', link: /\bAppRoutes\.freshMeat\b/ },
  { name: 'freshMeatStore', rnFile: '(app)/(tabs)/grocery/fresh-meat/stores/[storeId]/index.tsx', link: /\bfreshMeatStoreDetails\b/ },
  { name: 'freshMeatProduct', rnFile: '(app)/(tabs)/grocery/fresh-meat/stores/[storeId]/product/[productId].tsx', link: /\bfreshMeatProductDetails\b/ },
  { name: 'freshMeatCart', rnFile: '(app)/(tabs)/grocery/fresh-meat/cart.tsx', link: /\bAppRoutes\.freshMeatCart\b/ },
  { name: 'freshMeatCheckout', rnFile: '(app)/(tabs)/grocery/fresh-meat/checkout.tsx', link: /\bAppRoutes\.freshMeatCheckout\b/ },
  { name: 'electronics', rnFile: '(app)/(tabs)/grocery/electronics/index.tsx', link: /\bAppRoutes\.electronics\b/ },
  { name: 'electronicsStore', rnFile: '(app)/(tabs)/grocery/electronics/stores/[storeId]/index.tsx', link: /\belectronicsStoreDetails\b/ },
  { name: 'electronicsProduct', rnFile: '(app)/(tabs)/grocery/electronics/stores/[storeId]/product/[productId].tsx', link: /\belectronicsProductDetails\b/ },
  { name: 'electronicsCart', rnFile: '(app)/(tabs)/grocery/electronics/cart.tsx', link: /\bAppRoutes\.electronicsCart\b/ },
  { name: 'electronicsCheckout', rnFile: '(app)/(tabs)/grocery/electronics/checkout.tsx', link: /\bAppRoutes\.electronicsCheckout\b/ },

  // Pharmacy
  { name: 'pharmacy', rnFile: '(app)/(tabs)/pharmacy/index.tsx', link: /\bAppRoutes\.pharmacy\b/ },
  { name: 'pharmacyStore', rnFile: '(app)/(tabs)/pharmacy/stores/[storeId]/index.tsx', link: /\bpharmacyStoreDetails\(/ },
  { name: 'pharmacyProduct', rnFile: '(app)/(tabs)/pharmacy/stores/[storeId]/product/[productId].tsx', link: /\bpharmacyProductDetails\(/ },
  { name: 'pharmacyCart', rnFile: '(app)/(tabs)/pharmacy/cart.tsx', link: /\bAppRoutes\.pharmacyCart\b/ },
  { name: 'pharmacyCheckout', rnFile: '(app)/(tabs)/pharmacy/checkout.tsx', link: /\bAppRoutes\.pharmacyCheckout\b/ },

  // Legacy aliases (redirects)
  { name: 'home', rnFile: '(app)/home.tsx', link: /\bAppRoutes\.home\b|'\/home'/, redirect: true,
    deepLinkOnly: 'legacy alias, redirects to /app' },
  { name: 'categories', rnFile: '(app)/categories.tsx', link: /\bAppRoutes\.categories\b|'\/categories'/, redirect: true,
    deepLinkOnly: 'legacy alias, redirects to /services' },
  { name: 'cart', rnFile: '(app)/cart.tsx', link: /\bAppRoutes\.cart\b|'\/cart'/, redirect: true,
    deepLinkOnly: 'legacy alias, redirects to /food/cart' },
  { name: 'checkout', rnFile: '(app)/checkout.tsx', link: /\bAppRoutes\.checkout\b|'\/checkout'/, redirect: true,
    deepLinkOnly: 'legacy alias, redirects to /food/checkout' },
  { name: 'restaurants', rnFile: '(app)/restaurants/index.tsx', link: /\bAppRoutes\.restaurants\b|'\/restaurants'/, redirect: true,
    deepLinkOnly: 'legacy alias, redirects to /food' },
  { name: 'restaurant', rnFile: '(app)/restaurants/[restaurantId].tsx', link: /'\/restaurants\/\[restaurantId\]'/, redirect: true,
    deepLinkOnly: 'legacy alias, redirects to a restaurant details path' },
];

/** `AppRoutes` constants that are not registered routes. */
const NOT_A_ROUTE: Record<string, string> = {
  welcomeRevisitParam: 'query-flag name, not a path',
  welcomeRevisit: 'the welcome route plus a query flag',
  foodRestaurants: 'path prefix only; no GoRoute is registered for it',
  groceryStores: 'path prefix only; no GoRoute is registered for it',
  pharmacyStores: 'path prefix only; no GoRoute is registered for it',
};

/** Files under `src/app/` with no Flutter `AppRoutes` constant. */
const RN_ONLY: Record<string, string> = {
  '+not-found.tsx': "Expo Router's unmatched-route screen; Flutter uses GoRouter's errorBuilder (NotFoundScreen)",
  'reset-callback.tsx': "password-recovery deep-link landing; Flutter handles it in AppRouter's auth listener",
  'dev-gallery.tsx': 'development-only component gallery',
  'theme-preview.tsx': 'development-only theme token preview',
};

/** Reads every `static const name = '...'` string in app_routes.dart, resolving `$name` references. */
function readFlutterRouteConstants(): Map<string, string> {
  const source = fs.readFileSync(FLUTTER_ROUTES_FILE, 'utf8');
  const constants = new Map<string, string>();
  for (const match of source.matchAll(/static const (\w+) = '([^']*)';/g)) {
    const resolved = match[2].replace(/\$\{?(\w+)\}?/g, (_whole, ref: string) => {
      const value = constants.get(ref);
      if (value === undefined) throw new Error(`app_routes.dart: ${match[1]} references unknown ${ref}`);
      return value;
    });
    constants.set(match[1], resolved);
  }
  return constants;
}

/** `(app)/(tabs)/food/restaurants/[restaurantId]/index.tsx` -> `/food/restaurants/:restaurantId`. */
function urlForRouteFile(rnFile: string): string {
  const segments = rnFile
    .replace(/\.tsx$/, '')
    .split('/')
    .filter((segment) => !/^\(.*\)$/.test(segment))
    .map((segment) => segment.replace(/^\[(\w+)\]$/, ':$1'));
  if (segments[segments.length - 1] === 'index') segments.pop();
  return `/${segments.join('/')}`;
}

function listFiles(dir: string): string[] {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    return entry.isDirectory() ? listFiles(full) : [full];
  });
}

function stripComments(source: string): string {
  return source.replace(/\/\*[\s\S]*?\*\//g, '').replace(/(^|[^:])\/\/.*$/gm, '$1');
}

const isTestFile = (file: string) => /\.test\.tsx?$/.test(file);

describe('Flutter route parity (issue #415)', () => {
  const flutterRoutes = readFlutterRouteConstants();
  const rowNames = new Set(FLUTTER_ROUTES.map((row) => row.name));

  it('reads the Flutter route constants', () => {
    // Guards the parser: a silent zero-match would make every check below pass.
    expect(flutterRoutes.size).toBeGreaterThan(50);
    expect(flutterRoutes.get('foodMenuItem')).toBe('/food/restaurants/:restaurantId/item/:itemId');
  });

  it('has a row for every Flutter route constant', () => {
    const missing = [...flutterRoutes.keys()].filter((name) => !rowNames.has(name) && !(name in NOT_A_ROUTE));
    expect(missing).toEqual([]);
  });

  it('has no row or exclusion for a name app_routes.dart does not define', () => {
    const unknown = [...rowNames, ...Object.keys(NOT_A_ROUTE)].filter((name) => !flutterRoutes.has(name));
    expect(unknown).toEqual([]);
  });

  it.each(FLUTTER_ROUTES.map((row) => [row.name, row] as const))(
    'AppRoutes.%s has an RN route file at the same path',
    (_name, row) => {
      expect(fs.existsSync(path.join(APP_DIR, row.rnFile))).toBe(true);
      expect(urlForRouteFile(row.rnFile)).toBe(flutterRoutes.get(row.name));
    },
  );

  it('maps every RN route file to a Flutter route or a documented RN-only route', () => {
    const mapped = new Set([...FLUTTER_ROUTES.map((row) => row.rnFile), ...Object.keys(RN_ONLY)]);
    const unmapped = listFiles(APP_DIR)
      .map((file) => path.relative(APP_DIR, file).split(path.sep).join('/'))
      .filter((file) => file.endsWith('.tsx') && !isTestFile(file) && !file.endsWith('_layout.tsx'))
      .filter((file) => !mapped.has(file));
    expect(unmapped).toEqual([]);
  });

  describe('in-app links (ports route_reachability_test.dart)', () => {
    // As in Flutter, the files that only declare or redirect routes are not
    // evidence of a link: the route constants, the redirect gate, navigator
    // layouts, and the legacy redirect route files.
    const redirectFiles = new Set(
      FLUTTER_ROUTES.filter((row) => row.redirect).map((row) => path.join(APP_DIR, row.rnFile)),
    );
    const sources = listFiles(SRC_DIR)
      .filter((file) => /\.tsx?$/.test(file) && !isTestFile(file))
      .filter((file) => !file.includes(`${path.sep}test-utils${path.sep}`))
      .filter((file) => !file.endsWith(path.join('platform', 'navigation', 'app-routes.ts')))
      .filter((file) => !file.endsWith(path.join('platform', 'navigation', 'redirect.ts')))
      .filter((file) => !file.endsWith('_layout.tsx') && !redirectFiles.has(file))
      .map((file) => ({ file, source: stripComments(fs.readFileSync(file, 'utf8')) }));

    const linkedFrom = (row: RouteRow) =>
      sources
        .filter(({ file }) => file !== path.join(APP_DIR, row.rnFile))
        .filter(({ source }) => row.link.test(source))
        .map(({ file }) => path.relative(SRC_DIR, file));

    it.each(FLUTTER_ROUTES.filter((row) => !row.deepLinkOnly).map((row) => [row.name, row] as const))(
      'AppRoutes.%s is linked from somewhere in the app',
      (_name, row) => {
        expect(linkedFrom(row)).not.toEqual([]);
      },
    );

    it.each(
      FLUTTER_ROUTES.filter((row) => row.deepLinkOnly && !row.knownDivergence).map((row) => [row.name, row] as const),
    )('deep-link-only AppRoutes.%s really has no in-app link', (_name, row) => {
      expect(linkedFrom(row)).toEqual([]);
    });

    it.each(FLUTTER_ROUTES.filter((row) => row.knownDivergence).map((row) => [row.name, row] as const))(
      'AppRoutes.%s: known divergence from Flutter is still present (remove knownDivergence once fixed)',
      (_name, row) => {
        expect(linkedFrom(row)).not.toEqual([]);
      },
    );
  });
});
