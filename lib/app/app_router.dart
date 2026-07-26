import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/categories/presentation/categories_screen.dart';
import '../features/checkout/presentation/checkout_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/onboarding/presentation/onboarding_page_1.dart';
import '../features/onboarding/presentation/onboarding_page_2.dart';
import '../features/onboarding/presentation/onboarding_page_3.dart';
import '../features/onboarding/presentation/welcome_screen.dart';
import '../features/orders/presentation/orders_screen.dart';
import '../features/orders/presentation/track_order_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/rewards/presentation/rewards_profile_screen.dart';
import '../features/rewards/presentation/rewards_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/support/presentation/support_screen.dart';
import '../features/wallet/presentation/wallet_screen.dart';
import '../screens/addresses.dart';
import '../screens/cart.dart';
import '../screens/explore.dart';
import '../screens/payment_methods.dart';
import 'app_routes.dart';
import 'main_app_screen.dart';

class AppRouter {
  AppRouter._();

  static const _signedOutOnlyRoutes = {
    AppRoutes.root,
    AppRoutes.welcome,
    AppRoutes.login,
    AppRoutes.register,
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
    _page(AppRoutes.onboardingOne, const OnboardingPage1()),
    _page(AppRoutes.onboardingTwo, const OnboardingPage2()),
    _page(AppRoutes.onboardingThree, const OnboardingPage3()),
  ];

  // Every page in this map requires a valid Supabase session.
  static const Map<String, Widget> _protectedPages = {
    AppRoutes.mainApp: MainAppScreen(),
    AppRoutes.home: HomeScreen(),
    AppRoutes.categories: CategoriesScreen(),
    AppRoutes.explore: ExploreScreen(),
    AppRoutes.cart: CartScreen(),
    AppRoutes.checkout: CheckoutScreen(),
    AppRoutes.profile: ProfileScreen(),
    AppRoutes.orders: OrdersScreen(),
    AppRoutes.addresses: AddressesScreen(),
    AppRoutes.paymentMethods: PaymentMethodsScreen(),
    AppRoutes.settings: SettingsScreen(),
    AppRoutes.support: SupportScreen(),
    AppRoutes.wallet: WalletScreen(),
    AppRoutes.trackOrder: TrackOrderScreen(),
    AppRoutes.rewards: RewardsScreen(),
    AppRoutes.rewardsProfile: RewardsProfileScreen(),
  };

  static final List<RouteBase> _protectedRoutes = _protectedPages.entries
      .map((entry) => _page(entry.key, entry.value))
      .toList();

  static final _authRefresh = _AuthStateRefresh();

  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.welcome,
    refreshListenable: _authRefresh,
    redirect: _redirect,
    routes: [..._publicRoutes, ..._protectedRoutes],
  );

  static String? _redirect(BuildContext context, GoRouterState state) {
    final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
    final location = state.matchedLocation;
    final isProtected = _protectedPages.containsKey(location);

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

  // Most routes only need a path and a screen, so keep that boilerplate here.
  static GoRoute _page(String path, Widget screen) {
    return GoRoute(path: path, builder: (_, _) => screen);
  }
}

// Notifies GoRouter whenever Supabase restores, creates, or removes a session.
class _AuthStateRefresh extends ChangeNotifier {
  _AuthStateRefresh() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) => notifyListeners(),
    );
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
