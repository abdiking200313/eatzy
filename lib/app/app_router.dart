import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/theme.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/onboarding/presentation/onboarding_page_1.dart';
import '../features/onboarding/presentation/onboarding_page_2.dart';
import '../features/onboarding/presentation/onboarding_page_3.dart';
import '../features/onboarding/presentation/welcome_screen.dart';
import '../features/orders/presentation/track_order_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/rewards/presentation/rewards_profile_screen.dart';
import '../features/rewards/presentation/rewards_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/super_app/presentation/super_app_home_screen.dart';
import '../features/support/presentation/support_screen.dart';
import '../features/wallet/presentation/wallet_screen.dart';
import '../platform/activity/presentation/activity_screen.dart';
import '../screens/addresses.dart';
import '../screens/categories.dart';
import '../screens/explore.dart';
import '../screens/payment_methods.dart';
import '../services/food/presentation/checkout_screen.dart';
import '../services/food/presentation/food_cart_screen.dart';
import '../services/food/presentation/food_categories_screen.dart';
import '../services/food/presentation/food_explore_screen.dart';
import '../services/food/presentation/food_home_screen.dart';
import '../services/food/presentation/restaurant_screen.dart';
import '../services/grocery/presentation/grocery_cart_screen.dart';
import '../services/grocery/presentation/grocery_checkout_screen.dart';
import '../services/grocery/presentation/grocery_screen.dart';
import '../services/grocery/presentation/grocery_store_screen.dart';
import '../services/pharmacy/presentation/pharmacy_cart_screen.dart';
import '../services/pharmacy/presentation/pharmacy_catalog_screen.dart';
import '../services/pharmacy/presentation/pharmacy_checkout_screen.dart';
import '../services/pharmacy/presentation/pharmacy_store_list_screen.dart';
import 'app_routes.dart';
import 'main_app_screen.dart';
import 'service_module.dart';

/// Maps a `customer_activity.service_id` path segment (`food`, `grocery`,
/// or `pharmacy`) back to a [ServiceId] for [ZivoServiceTheme]ing the
/// `trackOrderDetails` route. An unrecognized or missing segment falls back
/// to [ServiceId.unknown] (neutral platform colors) rather than guessing a
/// vertical — `TrackOrderScreen` itself independently treats a mismatched
/// order lookup as "not found".
ServiceId _serviceIdFromPathSegment(String? raw) => switch (raw) {
  'food' => ServiceId.food,
  'grocery' => ServiceId.grocery,
  'pharmacy' => ServiceId.pharmacy,
  _ => ServiceId.unknown,
};

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

  // The four bottom-nav tabs. Each is its own StatefulShellBranch below, so
  // switching between them (and into a vertical, see _serviceBranches) keeps
  // every branch's own navigator/scroll/future state alive and leaves the
  // persistent bottom nav bar on screen — see issue #67.
  static const Map<String, Widget> _shellTabPages = {
    AppRoutes.mainApp: SuperAppHomeScreen(),
    AppRoutes.explore: ExploreScreen(),
    AppRoutes.activity: ActivityScreen(),
    AppRoutes.profile: ProfileScreen(),
  };

  // Food, grocery, and pharmacy are also StatefulShellBranches of the same
  // shell (not bottom-nav destinations themselves — they're reached by
  // `context.go` from a service card). Keeping each vertical's whole
  // sub-tree inside the shell, rather than as standalone top-level routes,
  // is what keeps the bottom nav bar visible while browsing a vertical.
  // foodExplore/foodRestaurant aren't listed here since they need custom
  // GoRoutes (query params / path params) — see the food branch below.
  static const Map<String, Widget> _foodPages = {
    AppRoutes.food: ZivoServiceTheme(
      serviceId: ServiceId.food,
      child: FoodHomeScreen(),
    ),
    AppRoutes.foodCategories: ZivoServiceTheme(
      serviceId: ServiceId.food,
      child: FoodCategoriesScreen(),
    ),
    AppRoutes.foodCart: ZivoServiceTheme(
      serviceId: ServiceId.food,
      child: CartScreen(),
    ),
    AppRoutes.foodCheckout: ZivoServiceTheme(
      serviceId: ServiceId.food,
      child: CheckoutScreen(),
    ),
  };

  static const Map<String, Widget> _groceryPages = {
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
  };

  static const Map<String, Widget> _pharmacyPages = {
    AppRoutes.pharmacy: ZivoServiceTheme(
      serviceId: ServiceId.pharmacy,
      child: PharmacyStoreListScreen(),
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

  // Pages that intentionally stay outside the shell: pushed full-screen,
  // with their own back button, and not part of the persistent bottom nav.
  // Unaffected by issue #67 — only the four tabs and the three verticals
  // above needed to move into the shell.
  static const Map<String, Widget> _standaloneProtectedPages = {
    AppRoutes.services: CategoriesScreen(),
    AppRoutes.addresses: AddressesScreen(),
    AppRoutes.paymentMethods: PaymentMethodsScreen(),
    AppRoutes.settings: SettingsScreen(),
    // Reachable both from Settings (normal session) and by tapping a
    // password-recovery email link (temporary recovery session) — both
    // already carry a valid Supabase session by the time this route loads.
    AppRoutes.resetPassword: ResetPasswordScreen(),
    AppRoutes.support: SupportScreen(),
    AppRoutes.wallet: WalletScreen(),
    AppRoutes.trackOrder: ZivoServiceTheme(
      serviceId: ServiceId.food,
      child: TrackOrderScreen(),
    ),
    AppRoutes.rewards: RewardsScreen(),
    AppRoutes.rewardsProfile: RewardsProfileScreen(),
  };

  static final List<RouteBase> _standaloneProtectedRoutes = [
    ..._standaloneProtectedPages.entries.map(
      (entry) => _page(entry.key, entry.value),
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
    GoRoute(
      path: AppRoutes.trackOrderDetails,
      builder: (_, state) {
        final serviceId = state.pathParameters['serviceId'];
        final orderId = state.pathParameters['orderId'];
        return ZivoServiceTheme(
          serviceId: _serviceIdFromPathSegment(serviceId),
          child: TrackOrderScreen(orderId: orderId, serviceId: serviceId),
        );
      },
    ),
  ];

  // The persistent bottom-nav shell: Home/Explore/Activity/Profile plus the
  // food/grocery/pharmacy verticals, each its own branch so branch-switching
  // (via `context.go` or `navigationShell.goBranch`) never tears down the
  // other branches' navigator state, and the nav bar built by MainAppScreen
  // stays on screen the whole time. See issue #67.
  static final StatefulShellRoute _shellRoute = StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) =>
        MainAppScreen(navigationShell: navigationShell),
    branches: [
      for (final entry in _shellTabPages.entries)
        StatefulShellBranch(routes: [_page(entry.key, entry.value)]),
      StatefulShellBranch(
        routes: [
          ..._foodPages.entries.map((entry) => _page(entry.key, entry.value)),
          GoRoute(
            // Reads an optional ?categoryId=&categoryName= pair, set when
            // reached from a category card in FoodCategoriesScreen, to
            // pre-filter the list.
            path: AppRoutes.foodExplore,
            builder: (_, state) => ZivoServiceTheme(
              serviceId: ServiceId.food,
              child: FoodExploreScreen(
                categoryId: state.uri.queryParameters['categoryId'],
                categoryName: state.uri.queryParameters['categoryName'],
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.foodRestaurant,
            builder: (_, state) => ZivoServiceTheme(
              serviceId: ServiceId.food,
              child: RestaurantScreen(
                restaurantId: state.pathParameters['restaurantId']!,
              ),
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          ..._groceryPages.entries.map(
            (entry) => _page(entry.key, entry.value),
          ),
          GoRoute(
            path: AppRoutes.groceryStore,
            builder: (_, state) => ZivoServiceTheme(
              serviceId: ServiceId.grocery,
              child: GroceryStoreScreen(
                storeId: state.pathParameters['storeId']!,
              ),
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          ..._pharmacyPages.entries.map(
            (entry) => _page(entry.key, entry.value),
          ),
          GoRoute(
            path: AppRoutes.pharmacyStore,
            builder: (_, state) => ZivoServiceTheme(
              serviceId: ServiceId.pharmacy,
              child: PharmacyCatalogScreen(
                storeId: state.pathParameters['storeId']!,
                storeName: state.uri.queryParameters['name'],
              ),
            ),
          ),
        ],
      ),
    ],
  );

  static final _authRefresh = _AuthStateRefresh();

  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.welcome,
    refreshListenable: _authRefresh,
    redirect: _redirect,
    routes: [..._publicRoutes, _shellRoute, ..._standaloneProtectedRoutes],
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
    return _standaloneProtectedPages.containsKey(location) ||
        _shellTabPages.containsKey(location) ||
        AppRoutes.isServicePath(location) ||
        AppRoutes.isRestaurantDetails(location) ||
        AppRoutes.isTrackOrderDetails(location) ||
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

  /// True when [path] is registered as an exact, static route (public or
  /// protected). Only matches literal paths — it does not resolve dynamic
  /// segments such as `:restaurantId`, since none of the callers this exists
  /// for (route-registration contract tests) need that. Deliberately built
  /// from the route lists directly rather than the `router` field, so it can
  /// be used from a plain unit test without a Supabase session having been
  /// initialized first.
  static bool hasRegisteredRoute(String path) {
    bool matches(RouteBase route) => route is GoRoute && route.path == path;
    final shellRoutes = _shellRoute.branches.expand((branch) => branch.routes);
    return _publicRoutes.any(matches) ||
        _standaloneProtectedRoutes.any(matches) ||
        shellRoutes.any(matches);
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
