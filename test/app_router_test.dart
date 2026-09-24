import 'package:chowflow/app/app_router.dart';
import 'package:chowflow/app/app_routes.dart';
import 'package:chowflow/app/not_found_screen.dart';
import 'package:chowflow/app/service_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('AppRouter.resolveRedirect', () {
    const merchantDashboardSubPath = '${AppRoutes.merchantDashboard}/orders';

    const cases = <_RedirectCase>[
      // Signed-in customers.
      _RedirectCase(
        'a restored session is sent from welcome to the app',
        AppRoutes.welcome,
        loggedIn: true,
        expected: AppRoutes.mainApp,
      ),
      _RedirectCase(
        'a restored session is sent away from register',
        AppRoutes.register,
        loggedIn: true,
        expected: AppRoutes.mainApp,
      ),
      _RedirectCase(
        'a logged-in user is sent away from forgot password',
        AppRoutes.forgotPassword,
        loggedIn: true,
        expected: AppRoutes.mainApp,
      ),
      _RedirectCase(
        'a logged-in user (recovery or normal session) can reset password',
        AppRoutes.resetPassword,
        loggedIn: true,
        expected: null,
      ),
      // Signed-out visitors.
      _RedirectCase(
        'a signed-out user is sent to login for protected routes',
        AppRoutes.wallet,
        expected: AppRoutes.login,
      ),
      _RedirectCase(
        'a signed-out user may reach forgot password',
        AppRoutes.forgotPassword,
        expected: null,
      ),
      _RedirectCase(
        'a signed-out user is sent to login for reset password',
        AppRoutes.resetPassword,
        expected: AppRoutes.login,
      ),
      _RedirectCase(
        'a signed-out visitor is sent to login, not the merchant dashboard',
        AppRoutes.merchantDashboard,
        expected: AppRoutes.login,
      ),
      // Onboarding first-launch gating (issue #15).
      _RedirectCase(
        'a first-time signed-out visitor stays on welcome',
        AppRoutes.welcome,
        expected: null,
      ),
      _RedirectCase(
        'a returning signed-out user goes from welcome straight to login',
        AppRoutes.welcome,
        seenOnboarding: true,
        expected: AppRoutes.login,
      ),
      _RedirectCase(
        'a returning signed-out user can reopen welcome on purpose (the '
        'back button on login/register)',
        AppRoutes.welcome,
        seenOnboarding: true,
        revisit: true,
        expected: null,
      ),
      _RedirectCase(
        'a signed-in user is sent to the app even with the revisit flag',
        AppRoutes.welcome,
        loggedIn: true,
        seenOnboarding: true,
        revisit: true,
        expected: AppRoutes.mainApp,
      ),
      _RedirectCase(
        'a returning signed-out user is not diverted away from login',
        AppRoutes.login,
        seenOnboarding: true,
        expected: null,
      ),
      _RedirectCase(
        'a returning but signed-in user goes to the app, not login',
        AppRoutes.welcome,
        loggedIn: true,
        seenOnboarding: true,
        expected: AppRoutes.mainApp,
      ),
      // Merchant dashboard routing (issues #232, #236).
      _RedirectCase(
        'a merchant/admin restored on welcome lands on the merchant dashboard',
        AppRoutes.welcome,
        loggedIn: true,
        merchant: true,
        expected: AppRoutes.merchantDashboard,
      ),
      _RedirectCase(
        'a merchant/admin is redirected away from login',
        AppRoutes.login,
        loggedIn: true,
        merchant: true,
        expected: AppRoutes.merchantDashboard,
      ),
      _RedirectCase(
        'a merchant/admin can stay on the merchant dashboard',
        AppRoutes.merchantDashboard,
        loggedIn: true,
        merchant: true,
        expected: null,
      ),
      _RedirectCase(
        'a merchant/admin can stay on a merchant dashboard sub-path',
        merchantDashboardSubPath,
        loggedIn: true,
        merchant: true,
        expected: null,
      ),
      _RedirectCase(
        'a merchant/admin can still complete a password reset '
        '(recovery-session exemption)',
        AppRoutes.resetPassword,
        loggedIn: true,
        merchant: true,
        expected: null,
      ),
    ];

    for (final c in cases) {
      test(c.why, () {
        expect(
          AppRouter.resolveRedirect(
            isLoggedIn: c.loggedIn,
            isProtected: AppRouter.isProtectedLocation(c.location),
            location: c.location,
            isMerchant: c.merchant,
            hasSeenOnboarding: c.seenOnboarding,
            revisitWelcome: c.revisit,
          ),
          c.expected,
        );
      });
    }

    const customerRoutes = [
      AppRoutes.mainApp,
      AppRoutes.food,
      AppRoutes.settings,
      AppRoutes.wallet,
      AppRoutes.grocery,
      AppRoutes.pharmacy,
      AppRoutes.profile,
      AppRoutes.trackOrder,
      AppRoutes.foodCheckout,
    ];

    test('a merchant/admin is blocked from every customer route (#236), '
        'while a customer session reaches all of them', () {
      for (final location in customerRoutes) {
        String? redirectFor({required bool merchant}) =>
            AppRouter.resolveRedirect(
              isLoggedIn: true,
              isProtected: AppRouter.isProtectedLocation(location),
              location: location,
              isMerchant: merchant,
            );

        expect(
          redirectFor(merchant: true),
          AppRoutes.merchantDashboard,
          reason: '$location should send a merchant to the dashboard',
        );
        expect(
          redirectFor(merchant: false),
          isNull,
          reason: '$location should remain reachable by a customer',
        );
      }
    });
  });

  test('isProtectedLocation gates every customer, service and merchant '
      'route, but not the pre-sign-in auth routes', () {
    final protected = [
      // Bottom-nav shell tabs — each its own StatefulShellBranch (#67).
      AppRoutes.mainApp,
      AppRoutes.explore,
      AppRoutes.activity,
      AppRoutes.profile,
      // Service subtrees.
      AppRoutes.food,
      AppRoutes.groceryCart,
      AppRoutes.pharmacyCheckout,
      AppRoutes.groceryStoreDetails('bakaal-fresh'),
      AppRoutes.pharmacyStoreDetails('legacy-pharmacy'),
      AppRoutes.trackOrder,
      AppRoutes.trackOrderDetailsPath(serviceId: 'grocery', orderId: 'o-2'),
      AppRoutes.wallet,
      AppRoutes.resetPassword,
      AppRoutes.merchantDashboard,
    ];
    for (final path in protected) {
      expect(AppRouter.isProtectedLocation(path), isTrue, reason: path);
    }
    for (final path in [
      AppRoutes.welcome,
      AppRoutes.login,
      AppRoutes.register,
      AppRoutes.forgotPassword,
    ]) {
      expect(AppRouter.isProtectedLocation(path), isFalse, reason: path);
    }
  });

  group('hasRegisteredRoute', () {
    test('parameterized and dashboard routes are registered', () {
      for (final route in [
        AppRoutes.merchantDashboard,
        AppRoutes.foodRestaurant,
        AppRoutes.groceryStore,
        AppRoutes.pharmacyStore,
        AppRoutes.trackOrderDetails,
      ]) {
        expect(AppRouter.hasRegisteredRoute(route), isTrue, reason: route);
      }
    });

    test('path-prefix-only constants, removed onboarding routes and unknown '
        'paths are not registered (see app_routes.dart)', () {
      for (final route in [
        AppRoutes.foodRestaurants,
        AppRoutes.groceryStores,
        AppRoutes.pharmacyStores,
        '/onboarding/one',
        '/onboarding/two',
        '/onboarding/three',
        '/this-path-does-not-exist',
      ]) {
        expect(AppRouter.hasRegisteredRoute(route), isFalse, reason: route);
      }
    });

    test('every ServiceDescriptor.entryRoute resolves to a registered route '
        '(issue #69)', () {
      for (final module in ServiceRegistry.modules) {
        expect(
          AppRouter.hasRegisteredRoute(module.entryRoute),
          isTrue,
          reason:
              '${module.id} entryRoute "${module.entryRoute}" has no '
              'matching GoRoute',
        );
      }
    });

    test('every details_route the customer_activity SQL view can produce '
        'resolves to a registered route (issue #69)', () {
      // Mirrors the literal `details_route` values selected by the
      // `customer_activity` view as currently (re)defined in
      // supabase/migrations/20260815153920_remove_cleaning_vertical.sql
      // (food/grocery/pharmacy branches; the earlier cleaning branch was
      // dropped by issue #50). There is no SQL execution available from a
      // Dart unit test, so this list is a manually kept mirror of that
      // view's `select` branches — if a future migration changes, adds, or
      // removes a `details_route` literal in customer_activity, update this
      // list to match, in the same change.
      const sqlViewDetailsRoutes = [
        AppRoutes.food,
        AppRoutes.grocery,
        AppRoutes.pharmacy,
      ];

      for (final route in sqlViewDetailsRoutes) {
        expect(
          AppRouter.hasRegisteredRoute(route),
          isTrue,
          reason:
              'customer_activity details_route "$route" has no matching '
              'GoRoute',
        );
      }
    });
  });

  test('path builders and predicates', () {
    expect(
      AppRoutes.restaurantDetails('restaurant-123'),
      '/food/restaurants/restaurant-123',
    );
    expect(AppRoutes.isRestaurantDetails('/restaurants/r-1'), isTrue);
    expect(AppRoutes.isRestaurantDetails('/food/restaurants/r-1'), isTrue);
    expect(AppRoutes.isRestaurantDetails('/restaurants'), isFalse);

    expect(
      AppRoutes.groceryStoreDetails('bakaal-fresh'),
      '/grocery/stores/bakaal-fresh',
    );
    expect(
      AppRoutes.isGroceryStoreDetails('/grocery/stores/bakaal-fresh'),
      isTrue,
    );
    expect(AppRoutes.isGroceryStoreDetails('/grocery/cart'), isFalse);
    expect(AppRoutes.isGroceryStoreDetails('/grocery'), isFalse);

    expect(
      AppRoutes.pharmacyStoreDetails('legacy-pharmacy'),
      '/pharmacy/stores/legacy-pharmacy',
    );

    final trackPath = AppRoutes.trackOrderDetailsPath(
      serviceId: 'food',
      orderId: 'order 1/2',
    );
    expect(trackPath, '/track-order/food/order%201%2F2');
    expect(AppRoutes.isTrackOrderDetails(trackPath), isTrue);
    expect(AppRoutes.isTrackOrderDetails(AppRoutes.trackOrder), isFalse);

    expect(
      AppRouter.isWelcomeRevisit(Uri.parse(AppRoutes.welcomeRevisit)),
      isTrue,
    );
    expect(AppRouter.isWelcomeRevisit(Uri.parse(AppRoutes.welcome)), isFalse);
    expect(
      AppRouter.isWelcomeRevisit(Uri.parse('${AppRoutes.welcome}?revisit=no')),
      isFalse,
    );
  });

  testWidgets('NotFoundScreen shows a message and a way back to a known route '
      '(issue #40)', (tester) async {
    final router = GoRouter(
      initialLocation: '/this-path-does-not-exist',
      routes: [
        GoRoute(
          path: AppRoutes.mainApp,
          builder: (_, _) => const Scaffold(body: Text('home screen')),
        ),
      ],
      errorBuilder: (_, _) => const NotFoundScreen(),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text("We couldn't find that page"), findsOneWidget);
    expect(find.text('home screen'), findsNothing);

    await tester.tap(find.text('Go to home'));
    await tester.pumpAndSettle();

    expect(find.text('home screen'), findsOneWidget);
    expect(find.text("We couldn't find that page"), findsNothing);
  });
}

class _RedirectCase {
  const _RedirectCase(
    this.why,
    this.location, {
    this.loggedIn = false,
    this.merchant = false,
    this.seenOnboarding = false,
    this.revisit = false,
    required this.expected,
  });

  final String why;
  final String location;
  final bool loggedIn;
  final bool merchant;
  final bool seenOnboarding;
  final bool revisit;
  final String? expected;
}
