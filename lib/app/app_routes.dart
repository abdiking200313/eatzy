class AppRoutes {
  AppRoutes._();

  // Public routes
  static const root = '/';
  static const welcome = '/welcome';

  // The welcome/onboarding slides opened on purpose (the back button on
  // login/register). A returning signed-out user is normally redirected
  // from [welcome] straight to login (issue #15); this query flag is the
  // one exception, so "back to onboarding" doesn't bounce off that
  // redirect. Same route, same screen -- only the redirect reads the flag.
  static const welcomeRevisitParam = 'revisit';
  static const welcomeRevisit = '$welcome?$welcomeRevisitParam=true';

  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  // Requires an active Supabase session (a normal login, or the temporary
  // session created by tapping a password-recovery email link).
  static const resetPassword = '/reset-password';

  // There is deliberately no standalone `/onboarding/*` route. The
  // onboarding slides (`OnboardingPage1/2/3`) only ever render as `PageView`
  // children embedded inside `WelcomeScreen` -- a bare, direct route to one
  // slide had no AppBar, skip button, or pagination and was a dead end for
  // anyone who reached it (issue #15). Reach the real flow via [welcome].

  // Login-required routes
  static const mainApp = '/app';
  static const home = '/home';
  static const services = '/services';
  static const activity = '/activity';

  // The merchant dashboard (issue #232, superseding the standalone
  // `merchant_app` project from issue #132): `AppRouter` sends a signed-in
  // `merchant`/`admin` account here instead of [mainApp], right after
  // sign-in and again on session-restore at app start. There is no
  // customer-facing link to this route and no switcher back to the
  // customer home for the same account -- see the router's redirect logic.
  static const merchantDashboard = '/merchant';

  // Food service
  static const food = '/food';

  // Not a navigable destination on its own — no screen renders a bare
  // "/food/restaurants" list, `food` already serves that role. This exists
  // only as a shared path-segment prefix for `foodRestaurant` (the
  // registered per-restaurant route) and for `restaurantDetails`/
  // `isRestaurantDetails` below. Intentionally has no matching GoRoute; see
  // issue #69.
  static const foodRestaurants = '$food/restaurants';
  static const foodRestaurant = '$foodRestaurants/:restaurantId';
  static const foodCategories = '$food/categories';
  static const foodExplore = '$food/explore';
  static const foodCart = '$food/cart';
  static const foodCheckout = '$food/checkout';

  // Grocery service
  static const grocery = '/grocery';

  // Not a navigable destination on its own — no screen renders a bare
  // "/grocery/stores" list, `grocery` already serves that role (the store
  // list screen). This exists only as a shared path-segment prefix for
  // `groceryStore` (the registered per-store route) and for
  // `groceryStoreDetails`/`isGroceryStoreDetails` below. Mirrors
  // `foodRestaurants` in shape.
  static const groceryStores = '$grocery/stores';
  static const groceryStore = '$groceryStores/:storeId';
  static const groceryCart = '$grocery/cart';
  static const groceryCheckout = '$grocery/checkout';

  // Fresh Meat and Electronics are grocery-engine store lists filtered by
  // `grocery_stores.store_type` — they share the grocery cart, checkout and
  // store pages.
  static const freshMeat = '$grocery/fresh-meat';
  static const electronics = '$grocery/electronics';

  // Pharmacy service
  static const pharmacy = '/pharmacy';

  // Not a navigable destination on its own — `pharmacy` already serves as
  // the searchable pharmacy list (issue #141), mirroring `foodRestaurants`.
  // This exists only as a shared path-segment prefix for `pharmacyStore`
  // (the registered per-pharmacy route) and for `pharmacyStoreDetails`
  // below.
  static const pharmacyStores = '$pharmacy/stores';
  static const pharmacyStore = '$pharmacyStores/:storeId';
  static const pharmacyCart = '$pharmacy/cart';
  static const pharmacyCheckout = '$pharmacy/checkout';

  // Legacy food routes kept for compatibility.
  static const restaurants = '/restaurants';
  static const restaurant = '$restaurants/:restaurantId';
  static const categories = '/categories';
  static const explore = '/explore';
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const profile = '/profile';
  static const addresses = '/addresses';
  static const settings = '/settings';
  static const support = '/support';

  // Static legal documents (issue #37), reached from Settings → Privacy
  // Policy / Terms & Conditions. In-app content only — see
  // `LegalDocumentScreen`'s doc comment for the app-store-hosting gap this
  // does not close.
  static const privacyPolicy = '/settings/privacy-policy';
  static const termsOfService = '/settings/terms-of-service';

  // Bare `/track-order` is kept for backward compatibility with any old
  // deep link that has no order to point at — `TrackOrderScreen` renders a
  // "no order selected" empty state for it rather than crashing (see
  // issue #43). `trackOrderDetails` is the real, navigable form: reached
  // from a "Track order" action on an `ActivityScreen` row via
  // `trackOrderDetailsPath`, which keys the lookup by both the order's
  // `service_id` and its `customer_activity` row id.
  static const trackOrder = '/track-order';
  static const trackOrderDetails = '$trackOrder/:serviceId/:orderId';

  static String restaurantDetails(String restaurantId) =>
      '$foodRestaurants/${Uri.encodeComponent(restaurantId)}';

  static bool isRestaurantDetails(String location) =>
      location.startsWith('$foodRestaurants/') ||
      location.startsWith('$restaurants/');

  static String groceryStoreDetails(String storeId) =>
      '$groceryStores/${Uri.encodeComponent(storeId)}';

  static bool isGroceryStoreDetails(String location) =>
      location.startsWith('$groceryStores/');

  static String pharmacyStoreDetails(String storeId) =>
      '$pharmacyStores/${Uri.encodeComponent(storeId)}';

  static String trackOrderDetailsPath({
    required String serviceId,
    required String orderId,
  }) =>
      '$trackOrder/${Uri.encodeComponent(serviceId)}/'
      '${Uri.encodeComponent(orderId)}';

  static bool isTrackOrderDetails(String location) =>
      location.startsWith('$trackOrder/');

  static bool isServicePath(String location) => const [
    food,
    grocery,
    pharmacy,
  ].any((prefix) => location == prefix || location.startsWith('$prefix/'));
}
