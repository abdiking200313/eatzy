//import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_gate.dart';
import '../screens/addresses.dart';
import '../screens/cart.dart';
import '../screens/categories.dart';
import '../screens/checkout.dart';
import '../screens/explore.dart';
//import '../screens/categories.dart';
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
  static const String root = '/';
  static const String welcome = '/welcome';
  static const String auth = '/auth';
  static const String mainApp = '/app';
  static const String home = '/home';
  static const String login = '/login';
  static const String register = '/register';
  static const String categories = '/categories';
  static const String explore = '/explore';
  static const String favorites = '/favorites';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String profile = '/profile';
  static const String orders = '/orders';
  static const String addresses = '/addresses';
  static const String paymentMethods = '/payment-methods';
  static const String settings = '/settings';
  static const String support = '/support';
  static const String helpSupport = '/help-support';
  static const String wallet = '/wallet';
  static const String trackOrder = '/track-order';
  static const String rewards = '/rewards';
  static const String rewardsProfile = '/rewards-profile';
  static const String onboardingOne = '/onboarding/one';
  static const String onboardingTwo = '/onboarding/two';
  static const String onboardingThree = '/onboarding/three';
}

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.welcome,
    routes: [
      GoRoute(
        path: AppRoutes.root,
        redirect: (_, __) => AppRoutes.welcome,
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) => const AuthGate(),
      ),
      GoRoute(
        path: AppRoutes.mainApp,
        builder: (context, state) => const MainAppScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.categories,
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: AppRoutes.explore,
        builder: (context, state) => const ExploreScreen(),
      ),
      GoRoute(
        path: AppRoutes.cart,
        builder: (context, state) => const CartScreenFull(),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        builder: (context, state) => const CheckoutScreenFull(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreenFull(),
      ),
      GoRoute(
        path: AppRoutes.orders,
        builder: (context, state) => const OrdersScreenFull(),
      ),
      GoRoute(
        path: AppRoutes.addresses,
        builder: (context, state) => const AddressesScreenFull(),
      ),
      GoRoute(
        path: AppRoutes.paymentMethods,
        builder: (context, state) => const PaymentMethodsScreenFull(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreenFull(),
      ),
      GoRoute(
        path: AppRoutes.support,
        builder: (context, state) => const SupportScreenFull(),
      ),
      GoRoute(
        path: AppRoutes.helpSupport,
        builder: (context, state) => const HelpSupportScreenFull(),
      ),
      GoRoute(
        path: AppRoutes.wallet,
        builder: (context, state) => const WalletScreenFull(),
      ),
      GoRoute(
        path: AppRoutes.trackOrder,
        builder: (context, state) => const TrackOrderScreenFull(),
      ),
      GoRoute(
        path: AppRoutes.rewards,
        builder: (context, state) => const GamifiedScreenFull(),
      ),
      GoRoute(
        path: AppRoutes.rewardsProfile,
        builder: (context, state) => const GamifiedProfileScreenFull(),
      ),
      GoRoute(
        path: AppRoutes.onboardingOne,
        builder: (context, state) => const OnboardingPage1(),
      ),
      GoRoute(
        path: AppRoutes.onboardingTwo,
        builder: (context, state) => const OnboardingPage2(),
      ),
      GoRoute(
        path: AppRoutes.onboardingThree,
        builder: (context, state) => const OnboardingPage3(),
      ),
    ],
  );
}
