import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/theme.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/checkout/presentation/checkout_screen.dart';
import '../features/onboarding/presentation/onboarding_page_1.dart';
import '../features/onboarding/presentation/onboarding_page_2.dart';
import '../features/onboarding/presentation/onboarding_page_3.dart';
import '../features/onboarding/presentation/welcome_screen.dart';
import '../features/orders/presentation/track_order_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/restaurant/presentation/restaurant_screen.dart';
import '../features/rewards/presentation/rewards_profile_screen.dart';
import '../features/rewards/presentation/rewards_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/support/presentation/support_screen.dart';
import '../features/wallet/presentation/wallet_screen.dart';
import '../screens/addresses.dart';
import '../screens/cart.dart';
import '../screens/categories.dart';
import '../screens/explore.dart';
import '../screens/payment_methods.dart';
import '../services/food/presentation/food_categories_screen.dart';
import '../services/food/presentation/food_explore_screen.dart';
import '../services/food/presentation/food_home_screen.dart';
import '../services/grocery/presentation/grocery_cart_screen.dart';
import '../services/grocery/presentation/grocery_checkout_screen.dart';
import '../services/grocery/presentation/grocery_screen.dart';
import '../services/pharmacy/presentation/pharmacy_cart_screen.dart';
import '../services/pharmacy/presentation/pharmacy_catalog_screen.dart';
import '../services/pharmacy/presentation/pharmacy_checkout_screen.dart';
import 'app_routes.dart';
import 'main_app_screen.dart';
import 'service_module.dart';

class AppRouter {
  AppRouter._();

  static const _signedOutOnlyRoutes = {
    AppRoutes.root,
    AppRoutes.welcome,
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.forgotPassword,
    AppRoutes.onboardingOne,
    AppRoutes.onboardingTwo,
    AppRoutes.onboardingThree,
  };

  // These pages can be opened without a Supabase session.
  static final List<RouteBase> _publicRoutes = [
    GoRoute(path: AppRoutes.root, redirect: (_, _) => AppRoutes.welcome),
    _page(AppRoutes.welcome, const WelcomeScreen()),
    _page(AppRoutes.login, const LoginScreen()),
    _page(AppRoutes.register, const RegisterScreen()),
    _page(AppRoutes.forgotPassword, const ForgotPasswordScreen()),
    _page(AppRoutes.onboardingOne, const OnboardingPage1()),
    _page(AppRoutes.onboardingTwo, const OnboardingPage2()),
    _page(AppRoutes.onboardingThree, const OnboardingPage3()),
  ];

  // Every page in this map requires a valid Supabase session.
  static const Map<String, Widget> _protectedPages = {
    AppRoutes.mainApp: MainAppScreen(),
    AppRoutes.services: CategoriesScreen(),
    // No context.push/go targets this path directly — ExploreScreen's
    // content is already reachable as the "Explore" bottom-nav tab inside
    // MainAppScreen (an IndexedStack swap, not a router push). It also
    // renders the same ServiceRegistry.modules list as CategoriesScreen in a
    // different card style; see test/route_reachability_test.dart (#71).
    AppRoutes.explore: ExploreScreen(),
    AppRoutes.activity: MainAppScreen(initialIndex: 2),
    // Same story as /explore above: reachable as the "Profile" bottom-nav
    // tab, the standalone route is deep-link-only (#71).
    AppRoutes.profile: ProfileScreen(),
    AppRoutes.addresses: AddressesScreen(),
    AppRoutes.paymentMethods: PaymentMethodsScreen(),
    AppRoutes.settings: SettingsScreen(),
    // Reachable both from Settings (normal session) and by tapping a
    // password-recovery email link (temporary recovery session) — both
    // already carry a valid Supabase session by the time this route loads.
    AppRoutes.resetPassword: ResetPasswordScreen(),
    AppRoutes.support: SupportScreen(),
    AppRoutes.wallet: WalletScreen(),
    // Deliberately deep-link-only for now: the natural entry point (an
    // activity item's detailsRoute) is owned by checkout/activity code that
    // concurrent in-flight PRs are actively reworking, and #43 tracks that
    // this screen's data is fake regardless. See test/route_reachability_test.dart (#71).
    AppRoutes.trackOrder: ZivoServiceTheme(
      serviceId: ServiceId.food,
      child: TrackOrderScreen(),
    ),
    // Real entry points added for #71: ProfileScreen's account options link
    // to /rewards, and RewardsScreen links to /rewards-profile.
    AppRoutes.rewards: RewardsScreen(),
    AppRoutes.rewardsProfile: RewardsProfileScreen(),
    AppRoutes.food: ZivoServiceTheme(
      serviceId: ServiceId.food,
      child: FoodHomeScreen(),
    ),
    AppRoutes.foodCategories: ZivoServiceTheme(
      serviceId: ServiceId.food,
      child: FoodCategoriesScreen(),
    ),
    AppRoutes.foodExplore: ZivoServiceTheme(
      serviceId: ServiceId.food,
      child: FoodExploreScreen(),
    ),
    AppRoutes.foodCart: ZivoServiceTheme(
      serviceId: ServiceId.food,
      child: CartScreen(),
    ),
    AppRoutes.foodCheckout: ZivoServiceTheme(
      serviceId: ServiceId.food,
      child: CheckoutScreen(),
    ),
    AppRoutes.grocery: ZivoServiceTheme(
      serviceId: ServiceId.grocery,
      child: GroceryScreen(),
    ),
    AppRoutes.groceryCart: ZivoServiceTheme(
      serviceId: ServiceId.grocery,
      child: GroceryCartScreen(),
    ),
    AppRoutes.groceryCheckout: ZivoServiceTheme(
      serviceId: ServiceId.grocery,
      child: GroceryCheckoutScreen(),
    ),
    AppRoutes.pharmacy: ZivoServiceTheme(
      serviceId: ServiceId.pharmacy,
      child: PharmacyCatalogScreen(),
    ),
    AppRoutes.pharmacyCart: ZivoServiceTheme(
      serviceId: ServiceId.pharmacy,
      child: PharmacyCartScreen(),
    ),
    AppRoutes.pharmacyCheckout: ZivoServiceTheme(
      serviceId: ServiceId.pharmacy,
      child: PharmacyCheckoutScreen(),
    ),
  };

  static final List<RouteBase> _protectedRoutes = [
    ..._protectedPages.entries.map((entry) => _page(entry.key, entry.value)),
    GoRoute(
      path: AppRoutes.foodRestaurant,
      builder: (_, state) => ZivoServiceTheme(
        serviceId: ServiceId.food,
        child: RestaurantScreen(
          restaurantId: state.pathParameters['restaurantId']!,
        ),
      ),
    ),
    GoRoute(path: AppRoutes.home, redirect: (_, _) => AppRoutes.mainApp),
    GoRoute(path: AppRoutes.categories, redirect: (_, _) => AppRoutes.services),
    GoRoute(path: AppRoutes.cart, redirect: (_, _) => AppRoutes.foodCart),
    GoRoute(
      path: AppRoutes.checkout,
      redirect: (_, _) => AppRoutes.foodCheckout,
    ),
    GoRoute(path: AppRoutes.restaurants, redirect: (_, _) => AppRoutes.food),
    GoRoute(
      path: AppRoutes.restaurant,
      redirect: (_, state) =>
          AppRoutes.restaurantDetails(state.pathParameters['restaurantId']!),
    ),
  ];

  static final _authRefresh = _AuthStateRefresh();

  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.welcome,
    refreshListenable: _authRefresh,
    redirect: _redirect,
    routes: [..._publicRoutes, ..._protectedRoutes],
  );

  static String? _redirect(BuildContext context, GoRouterState state) {
    final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
    final location = state.uri.path;
    final isProtected = isProtectedLocation(location);

    return resolveRedirect(
      isLoggedIn: isLoggedIn,
      isProtected: isProtected,
      location: location,
    );
  }

  static String? resolveRedirect({
    required bool isLoggedIn,
    required bool isProtected,
    required String location,
  }) {
    if (!isLoggedIn && isProtected) {
      return AppRoutes.login;
    }

    if (isLoggedIn && _signedOutOnlyRoutes.contains(location)) {
      return AppRoutes.mainApp;
    }

    return null;
  }

  static bool isProtectedLocation(String location) {
    return _protectedPages.containsKey(location) ||
        AppRoutes.isServicePath(location) ||
        AppRoutes.isRestaurantDetails(location) ||
        const {
          AppRoutes.home,
          AppRoutes.categories,
          AppRoutes.cart,
          AppRoutes.checkout,
          AppRoutes.restaurants,
        }.contains(location);
  }

  // Most routes only need a path and a screen, so keep that boilerplate here.
  static GoRoute _page(String path, Widget screen) {
    return GoRoute(path: path, builder: (_, _) => screen);
  }
}

// Notifies GoRouter whenever Supabase restores, creates, or removes a session.
class _AuthStateRefresh extends ChangeNotifier {
  _AuthStateRefresh() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      authState,
    ) {
      // Fired when the user taps a Supabase password-recovery email link
      // and the app receives the resulting deep link. Send them straight to
      // the reset-password screen instead of the normal signed-in redirect.
      if (authState.event == AuthChangeEvent.passwordRecovery) {
        AppRouter.router.go(AppRoutes.resetPassword);
      }
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
