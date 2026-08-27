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
  static const trackOrder = '/track-order';
  static const rewards = '/rewards';
  static const rewardsProfile = '/rewards-profile';

  static String restaurantDetails(String restaurantId) =>
      '$foodRestaurants/${Uri.encodeComponent(restaurantId)}';

  static bool isRestaurantDetails(String location) =>
      location.startsWith('$foodRestaurants/') ||
      location.startsWith('$restaurants/');

  static bool isServicePath(String location) => const [
    food,
    grocery,
    pharmacy,
  ].any((prefix) => location == prefix || location.startsWith('$prefix/'));
}
