class AppRoutes {
  AppRoutes._();

  // Public routes
  static const root = '/';
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  // Requires an active Supabase session (a normal login, or the temporary
  // session created by tapping a password-recovery email link).
  static const resetPassword = '/reset-password';
  static const onboardingOne = '/onboarding/one';
  static const onboardingTwo = '/onboarding/two';
  static const onboardingThree = '/onboarding/three';

  // Login-required routes
  static const mainApp = '/app';
  static const home = '/home';
  static const services = '/services';
  static const activity = '/activity';

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
  static const groceryCart = '$grocery/cart';
  static const groceryCheckout = '$grocery/checkout';

  // Pharmacy service
  static const pharmacy = '/pharmacy';
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
  static const paymentMethods = '/payment-methods';
  static const settings = '/settings';
  static const support = '/support';
  static const wallet = '/wallet';

  // Bare `/track-order` is kept for backward compatibility with any old
  // deep link that has no order to point at — `TrackOrderScreen` renders a
  // "no order selected" empty state for it rather than crashing (see
  // issue #43). `trackOrderDetails` is the real, navigable form: reached
  // from a "Track order" action on an `ActivityScreen` row via
  // `trackOrderDetailsPath`, which keys the lookup by both the order's
  // `service_id` and its `customer_activity` row id.
  static const trackOrder = '/track-order';
  static const trackOrderDetails = '$trackOrder/:serviceId/:orderId';
  static const rewards = '/rewards';
  static const rewardsProfile = '/rewards-profile';

  static String restaurantDetails(String restaurantId) =>
      '$foodRestaurants/${Uri.encodeComponent(restaurantId)}';

  static bool isRestaurantDetails(String location) =>
      location.startsWith('$foodRestaurants/') ||
      location.startsWith('$restaurants/');

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
