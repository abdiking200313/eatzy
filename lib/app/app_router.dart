import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/addresses.dart';
import '../screens/cart.dart';
import '../screens/categories.dart';
import '../screens/checkout.dart';
import '../screens/explore.dart';
import '../screens/gamified_profile_screen.dart';
import '../screens/gamified_screen.dart';
import '../screens/help_support.dart';
import '../screens/home.dart';
import '../screens/login.dart';
import '../screens/main_app.dart';
import '../screens/onboarding_page1.dart';
import '../screens/onboarding_page2.dart';
import '../screens/onboarding_page3.dart';
import '../screens/orders.dart';
import '../screens/payment_methods.dart';
import '../screens/profile.dart';
import '../screens/register.dart';
import '../screens/settings.dart';
import '../screens/support_screen.dart';
import '../screens/track_order_screen.dart';
import '../screens/wallet_screen.dart';
import '../screens/welcome.dart';

class AppRoutes {
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
  static const helpSupport = '/help-support';
  static const wallet = '/wallet';
  static const trackOrder = '/track-order';
  static const rewards = '/rewards';
  static const rewardsProfile = '/rewards-profile';
}

class AppRouter {
  AppRouter._();

  // These pages can be opened without a Supabase session.
  static final List<RouteBase> _publicRoutes = [
    GoRoute(path: AppRoutes.root, redirect: (_, __) => AppRoutes.welcome),
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
    AppRoutes.cart: CartScreenFull(),
    AppRoutes.checkout: CheckoutScreenFull(),
    AppRoutes.profile: ProfileScreenFull(),
    AppRoutes.orders: OrdersScreenFull(),
    AppRoutes.addresses: AddressesScreenFull(),
    AppRoutes.paymentMethods: PaymentMethodsScreenFull(),
    AppRoutes.settings: SettingsScreenFull(),
    AppRoutes.support: SupportScreenFull(),
    AppRoutes.helpSupport: HelpSupportScreenFull(),
    AppRoutes.wallet: WalletScreenFull(),
    AppRoutes.trackOrder: TrackOrderScreenFull(),
    AppRoutes.rewards: GamifiedScreenFull(),
    AppRoutes.rewardsProfile: GamifiedProfileScreenFull(),
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
    final isAuthPage =
        location == AppRoutes.login || location == AppRoutes.register;

    if (!isLoggedIn && isProtected) {
      return AppRoutes.login;
    }

    if (isLoggedIn && isAuthPage) {
      return AppRoutes.mainApp;
    }

    return null;
  }

  // Most routes only need a path and a screen, so keep that boilerplate here.
  static GoRoute _page(String path, Widget screen) {
    return GoRoute(path: path, builder: (_, __) => screen);
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
