class AppRoutes {
  AppRoutes._();

  // Public routes
  static const root = '/';
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const onboardingOne = '/onboarding/one';
  static const onboardingTwo = '/onboarding/two';
  static const onboardingThree = '/onboarding/three';

  // Login-required routes
  static const mainApp = '/app';
  static const home = '/home';
  static const categories = '/categories';
  static const explore = '/explore';
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const profile = '/profile';
  static const orders = '/orders';
  static const addresses = '/addresses';
  static const paymentMethods = '/payment-methods';
  static const settings = '/settings';
  static const support = '/support';
  static const wallet = '/wallet';
  static const trackOrder = '/track-order';
  static const rewards = '/rewards';
  static const rewardsProfile = '/rewards-profile';
}
