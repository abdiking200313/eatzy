/**
 * Ports the route-path constants and predicates from
 * `flutter_app/lib/app/app_routes.dart` that `redirect.ts` (and, later,
 * screens building links) need.
 *
 * This intentionally does not restate every `AppRoutes` constant from the
 * Dart file -- issue #358 already established the kebab-case path for each
 * screen directly in `src/app/**` (see `route-reachability.test.tsx`'s
 * `staticRoutes`/`dynamicRoutes`/`legacyRedirects` tables), so this file
 * only needs the subset `resolveRedirect`/`isProtectedLocation` (and a
 * plain `AppRoutes.foo` constant a future screen might want instead of a
 * hand-rolled string literal) actually reference.
 */

export const AppRoutes = {
  welcome: '/welcome',
  // Mirrors `AppRoutes.welcomeRevisitParam` -- the query flag set when the
  // welcome/onboarding slides are reopened on purpose (the back button on
  // login/register), so a returning user isn't bounced back to login by
  // `resolveRedirect`'s onboarding-skip rule. Same route, same screen --
  // only the redirect reads the flag.
  welcomeRevisitParam: 'revisit',
  // Mirrors `AppRoutes.welcomeRevisit` -- reopens the welcome/onboarding
  // slides with the revisit flag set, e.g. from the back button on
  // login/register when there's nothing to pop back to.
  welcomeRevisit: '/welcome?revisit=true',
  login: '/login',
  register: '/register',
  forgotPassword: '/forgot-password',
  // Reachable with a normal signed-in session or the temporary session
  // created by tapping a password-recovery email link.
  resetPassword: '/reset-password',

  mainApp: '/app',
  home: '/home',
  services: '/services',
  explore: '/explore',
  activity: '/activity',
  profile: '/profile',
  addresses: '/addresses',
  settings: '/settings',
  support: '/support',
  privacyPolicy: '/settings/privacy-policy',
  termsOfService: '/settings/terms-of-service',

  // The merchant dashboard. A signed-in `merchant`/`admin` account is
  // confined to this path (and any sub-path under it) for the whole
  // session -- see `isMerchantReachableLocation` in `redirect.ts`, and the
  // role check itself in `src/stores/merchant-session-gate.ts` (issue
  // #363). This file only carries the path itself.
  merchantDashboard: '/merchant',

  food: '/food',
  foodRestaurants: '/food/restaurants',
  foodCategories: '/food/categories',
  foodExplore: '/food/explore',
  foodCart: '/food/cart',
  foodCheckout: '/food/checkout',

  grocery: '/grocery',
  groceryStores: '/grocery/stores',
  groceryCart: '/grocery/cart',
  groceryCheckout: '/grocery/checkout',

  // Fresh Meat and Electronics run on the grocery engine (filtered by
  // `grocery_stores.store_type`) but each keeps its own cart (owner
  // decision, 2026-09-25) -- see `src/platform/services/registry.ts`.
  freshMeat: '/grocery/fresh-meat',
  electronics: '/grocery/electronics',

  pharmacy: '/pharmacy',
  pharmacyStores: '/pharmacy/stores',
  pharmacyCart: '/pharmacy/cart',
  pharmacyCheckout: '/pharmacy/checkout',

  // Legacy aliases kept for compatibility -- each redirects to the current
  // path (see `route-reachability.test.tsx`'s `legacyRedirects`), but still
  // counts as a protected location in the meantime.
  restaurants: '/restaurants',
  categories: '/categories',
  cart: '/cart',
  checkout: '/checkout',

  // Bare `/track-order` is kept for a deep link with no specific order to
  // point at. `trackOrderDetails` (see `trackOrderDetailsPath` below) is
  // the real, navigable form.
  trackOrder: '/track-order',
} as const;

/** Mirrors `AppRoutes.restaurantDetails`. */
export function restaurantDetails(restaurantId: string): string {
  return `${AppRoutes.foodRestaurants}/${encodeURIComponent(restaurantId)}`;
}

/** Mirrors `AppRoutes.isRestaurantDetails`. */
export function isRestaurantDetails(location: string): boolean {
  return (
    location.startsWith(`${AppRoutes.foodRestaurants}/`) ||
    location.startsWith(`${AppRoutes.restaurants}/`)
  );
}

/** Mirrors `AppRoutes.groceryStoreDetails`. */
export function groceryStoreDetails(storeId: string): string {
  return `${AppRoutes.groceryStores}/${encodeURIComponent(storeId)}`;
}

/** Mirrors `AppRoutes.isGroceryStoreDetails`. */
export function isGroceryStoreDetails(location: string): boolean {
  return location.startsWith(`${AppRoutes.groceryStores}/`);
}

/** Mirrors `AppRoutes.pharmacyStoreDetails`. */
export function pharmacyStoreDetails(storeId: string): string {
  return `${AppRoutes.pharmacyStores}/${encodeURIComponent(storeId)}`;
}

/** Mirrors `AppRoutes.trackOrderDetailsPath`. */
export function trackOrderDetailsPath(options: { serviceId: string; orderId: string }): string {
  return (
    `${AppRoutes.trackOrder}/${encodeURIComponent(options.serviceId)}/` +
    `${encodeURIComponent(options.orderId)}`
  );
}

/** Mirrors `AppRoutes.isTrackOrderDetails`. */
export function isTrackOrderDetails(location: string): boolean {
  return location.startsWith(`${AppRoutes.trackOrder}/`);
}

/** Mirrors `AppRoutes.isServicePath`. */
export function isServicePath(location: string): boolean {
  return [AppRoutes.food, AppRoutes.grocery, AppRoutes.pharmacy].some(
    (prefix) => location === prefix || location.startsWith(`${prefix}/`),
  );
}

// Mirrors `AppRouter._standaloneProtectedPages`'s keys.
const STANDALONE_PROTECTED_PATHS = new Set<string>([
  AppRoutes.services,
  AppRoutes.addresses,
  AppRoutes.settings,
  AppRoutes.resetPassword,
  AppRoutes.support,
  AppRoutes.privacyPolicy,
  AppRoutes.termsOfService,
  AppRoutes.trackOrder,
  AppRoutes.merchantDashboard,
]);

// Mirrors `AppRouter._shellTabPages`'s keys.
const SHELL_TAB_PATHS = new Set<string>([
  AppRoutes.mainApp,
  AppRoutes.explore,
  AppRoutes.activity,
  AppRoutes.profile,
]);

// Mirrors the extra legacy-alias set `isProtectedLocation` checks directly.
const LEGACY_PROTECTED_PATHS = new Set<string>([
  AppRoutes.home,
  AppRoutes.categories,
  AppRoutes.cart,
  AppRoutes.checkout,
  AppRoutes.restaurants,
]);

/** Mirrors `AppRouter.isProtectedLocation`. */
export function isProtectedLocation(location: string): boolean {
  return (
    STANDALONE_PROTECTED_PATHS.has(location) ||
    SHELL_TAB_PATHS.has(location) ||
    isServicePath(location) ||
    isRestaurantDetails(location) ||
    isTrackOrderDetails(location) ||
    // `merchantOrderDetail`/`merchantCatalog` carry path params, so the
    // exact `STANDALONE_PROTECTED_PATHS` lookup above never matches them on
    // its own.
    location.startsWith(`${AppRoutes.merchantDashboard}/`) ||
    LEGACY_PROTECTED_PATHS.has(location)
  );
}
