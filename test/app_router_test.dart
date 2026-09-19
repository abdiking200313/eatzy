import 'package:chowflow/app/app_router.dart';
import 'package:chowflow/app/app_routes.dart';
import 'package:chowflow/app/service_module.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRouter.resolveRedirect', () {
    test('sends a restored session from welcome to the app', () {
      final redirect = AppRouter.resolveRedirect(
        isLoggedIn: true,
        isProtected: false,
        location: AppRoutes.welcome,
      );

      expect(redirect, AppRoutes.mainApp);
    });

    test('sends a restored session away from register', () {
      final redirect = AppRouter.resolveRedirect(
        isLoggedIn: true,
        isProtected: false,
        location: AppRoutes.register,
      );

      expect(redirect, AppRoutes.mainApp);
    });

    test('sends a signed-out user to login for protected routes', () {
      final redirect = AppRouter.resolveRedirect(
        isLoggedIn: false,
        isProtected: true,
        location: AppRoutes.wallet,
      );

      expect(redirect, AppRoutes.login);
    });

    test('allows signed-out users to remain on welcome', () {
      final redirect = AppRouter.resolveRedirect(
        isLoggedIn: false,
        isProtected: false,
        location: AppRoutes.welcome,
      );

      expect(redirect, isNull);
    });

    test('allows signed-out users to reach forgot password', () {
      final redirect = AppRouter.resolveRedirect(
        isLoggedIn: false,
        isProtected: false,
        location: AppRoutes.forgotPassword,
      );

      expect(redirect, isNull);
    });

    test('sends an already-logged-in user away from forgot password', () {
      final redirect = AppRouter.resolveRedirect(
        isLoggedIn: true,
        isProtected: false,
        location: AppRoutes.forgotPassword,
      );

      expect(redirect, AppRoutes.mainApp);
    });

    test('sends a signed-out user to login for reset password', () {
      final redirect = AppRouter.resolveRedirect(
        isLoggedIn: false,
        isProtected: true,
        location: AppRoutes.resetPassword,
      );

      expect(redirect, AppRoutes.login);
    });

    test(
      'allows a logged-in user (recovery or normal session) to reset password',
      () {
        final redirect = AppRouter.resolveRedirect(
          isLoggedIn: true,
          isProtected: true,
          location: AppRoutes.resetPassword,
        );

        expect(redirect, isNull);
      },
    );
  });

  group('merchant dashboard routing (issue #232)', () {
    test('a merchant/admin account restored on welcome lands on the '
        'merchant dashboard, not the customer home', () {
      final redirect = AppRouter.resolveRedirect(
        isLoggedIn: true,
        isProtected: false,
        location: AppRoutes.welcome,
        isMerchant: true,
      );

      expect(redirect, AppRoutes.merchantDashboard);
    });

    test('a merchant/admin account is also redirected away from login', () {
      final redirect = AppRouter.resolveRedirect(
        isLoggedIn: true,
        isProtected: false,
        location: AppRoutes.login,
        isMerchant: true,
      );

      expect(redirect, AppRoutes.merchantDashboard);
    });

    test('a customer account (the default) still lands on the customer '
        'home, unaffected', () {
      final redirect = AppRouter.resolveRedirect(
        isLoggedIn: true,
        isProtected: false,
        location: AppRoutes.welcome,
      );

      expect(redirect, AppRoutes.mainApp);
    });

    test('the merchant dashboard is a registered, protected route', () {
      expect(AppRouter.hasRegisteredRoute(AppRoutes.merchantDashboard), isTrue);
      expect(
        AppRouter.isProtectedLocation(AppRoutes.merchantDashboard),
        isTrue,
      );
    });

    test(
      'a signed-out visitor is sent to login, not the merchant dashboard',
      () {
        final redirect = AppRouter.resolveRedirect(
          isLoggedIn: false,
          isProtected: true,
          location: AppRoutes.merchantDashboard,
        );

        expect(redirect, AppRoutes.login);
      },
    );
  });

  group('merchant/admin accounts are blocked from every customer route '
      '(issue #236)', () {
    test('a merchant/admin account is redirected away from a representative '
        'sample of customer-facing routes', () {
      for (final location in [
        AppRoutes.mainApp,
        AppRoutes.food,
        AppRoutes.settings,
        AppRoutes.wallet,
        AppRoutes.grocery,
        AppRoutes.pharmacy,
        AppRoutes.profile,
        AppRoutes.trackOrder,
        AppRoutes.foodCheckout,
      ]) {
        final redirect = AppRouter.resolveRedirect(
          isLoggedIn: true,
          isProtected: AppRouter.isProtectedLocation(location),
          location: location,
          isMerchant: true,
        );

        expect(
          redirect,
          AppRoutes.merchantDashboard,
          reason:
              '$location should redirect a merchant/admin session to '
              'the merchant dashboard',
        );
      }
    });

    test('a merchant/admin account can stay on the merchant dashboard '
        'itself', () {
      final redirect = AppRouter.resolveRedirect(
        isLoggedIn: true,
        isProtected: true,
        location: AppRoutes.merchantDashboard,
        isMerchant: true,
      );

      expect(redirect, isNull);
    });

    test('a merchant/admin account can stay on a sub-path under the '
        'merchant dashboard', () {
      final redirect = AppRouter.resolveRedirect(
        isLoggedIn: true,
        isProtected: true,
        location: '${AppRoutes.merchantDashboard}/orders',
        isMerchant: true,
      );

      expect(redirect, isNull);
    });

    test('a merchant/admin account can still complete a password reset '
        '(recovery-session exemption)', () {
      final redirect = AppRouter.resolveRedirect(
        isLoggedIn: true,
        isProtected: true,
        location: AppRoutes.resetPassword,
        isMerchant: true,
      );

      expect(redirect, isNull);
    });

    test("a customer account's navigation is completely unaffected by the "
        'merchant blanket block', () {
      for (final location in [
        AppRoutes.mainApp,
        AppRoutes.food,
        AppRoutes.settings,
        AppRoutes.wallet,
        AppRoutes.grocery,
        AppRoutes.pharmacy,
        AppRoutes.profile,
        AppRoutes.resetPassword,
      ]) {
        final redirect = AppRouter.resolveRedirect(
          isLoggedIn: true,
          isProtected: AppRouter.isProtectedLocation(location),
          location: location,
        );

        expect(
          redirect,
          isNull,
          reason: '$location should remain reachable by a customer session',
        );
      }
    });
  });

  group('onboarding first-launch gating (issue #15)', () {
    test('keeps a first-time signed-out visitor on welcome', () {
      final redirect = AppRouter.resolveRedirect(
        isLoggedIn: false,
        isProtected: false,
        location: AppRoutes.welcome,
      );

      expect(redirect, isNull);
    });

    test('sends a returning signed-out user (already seen onboarding) from '
        'welcome straight to login', () {
      final redirect = AppRouter.resolveRedirect(
        isLoggedIn: false,
        isProtected: false,
        location: AppRoutes.welcome,
        hasSeenOnboarding: true,
      );

      expect(redirect, AppRoutes.login);
    });

    test('lets a returning signed-out user reopen welcome on purpose (the '
        'back button on login/register)', () {
      final redirect = AppRouter.resolveRedirect(
        isLoggedIn: false,
        isProtected: false,
        location: AppRoutes.welcome,
        hasSeenOnboarding: true,
        revisitWelcome: true,
      );

      expect(redirect, isNull);
    });

    test('a signed-in user is still sent to the app even with the revisit '
        'flag', () {
      final redirect = AppRouter.resolveRedirect(
        isLoggedIn: true,
        isProtected: false,
        location: AppRoutes.welcome,
        hasSeenOnboarding: true,
        revisitWelcome: true,
      );

      expect(redirect, AppRoutes.mainApp);
    });

    test('welcomeRevisit is recognized only from its own query flag', () {
      expect(
        AppRouter.isWelcomeRevisit(Uri.parse(AppRoutes.welcomeRevisit)),
        isTrue,
      );
      expect(AppRouter.isWelcomeRevisit(Uri.parse(AppRoutes.welcome)), isFalse);
      expect(
        AppRouter.isWelcomeRevisit(
          Uri.parse('${AppRoutes.welcome}?revisit=no'),
        ),
        isFalse,
      );
    });

    test('does not divert a returning signed-out user away from login', () {
      final redirect = AppRouter.resolveRedirect(
        isLoggedIn: false,
        isProtected: false,
        location: AppRoutes.login,
        hasSeenOnboarding: true,
      );

      expect(redirect, isNull);
    });

    test('a returning but already-signed-in user still goes to the app, '
        'not login', () {
      final redirect = AppRouter.resolveRedirect(
        isLoggedIn: true,
        isProtected: false,
        location: AppRoutes.welcome,
        hasSeenOnboarding: true,
      );

      expect(redirect, AppRoutes.mainApp);
    });

    test('there is no standalone onboarding route left to redirect through '
        '(dead-end routes removed, see app_routes.dart)', () {
      expect(AppRouter.hasRegisteredRoute('/onboarding/one'), isFalse);
      expect(AppRouter.hasRegisteredRoute('/onboarding/two'), isFalse);
      expect(AppRouter.hasRegisteredRoute('/onboarding/three'), isFalse);
    });
  });

  group('restaurant routes', () {
    test('builds a restaurant details path', () {
      expect(
        AppRoutes.restaurantDetails('restaurant-123'),
        '/food/restaurants/restaurant-123',
      );
    });

    test('recognizes restaurant details as a protected path', () {
      expect(
        AppRoutes.isRestaurantDetails('/restaurants/restaurant-123'),
        isTrue,
      );
      expect(
        AppRoutes.isRestaurantDetails('/food/restaurants/restaurant-123'),
        isTrue,
      );
      expect(AppRoutes.isRestaurantDetails('/restaurants'), isFalse);
    });
  });

  group('grocery store routes (issue #140)', () {
    test('builds a grocery store details path', () {
      expect(
        AppRoutes.groceryStoreDetails('bakaal-fresh'),
        '/grocery/stores/bakaal-fresh',
      );
    });

    test('recognizes grocery store details by path prefix', () {
      expect(
        AppRoutes.isGroceryStoreDetails('/grocery/stores/bakaal-fresh'),
        isTrue,
      );
      expect(AppRoutes.isGroceryStoreDetails('/grocery/cart'), isFalse);
      expect(AppRoutes.isGroceryStoreDetails('/grocery'), isFalse);
    });

    test('groceryStores is deliberately not a registered route (path-prefix '
        'only, see app_routes.dart)', () {
      expect(AppRouter.hasRegisteredRoute(AppRoutes.groceryStores), isFalse);
      // The parameterized route it is a prefix of IS registered.
      expect(AppRouter.hasRegisteredRoute(AppRoutes.groceryStore), isTrue);
    });

    test('a grocery store details path is a protected route', () {
      expect(
        AppRouter.isProtectedLocation('/grocery/stores/bakaal-fresh'),
        isTrue,
      );
    });
  });

  group('super-app routes', () {
    test('recognizes every service subtree as protected', () {
      for (final path in [
        AppRoutes.food,
        AppRoutes.groceryCart,
        AppRoutes.pharmacyCheckout,
      ]) {
        expect(
          AppRouter.isProtectedLocation(path),
          isTrue,
          reason: '$path should require a signed-in customer',
        );
      }
    });
  });

  group('shell tab routes', () {
    test('recognizes every bottom-nav tab as protected', () {
      // These four paths are each their own StatefulShellBranch inside the
      // persistent bottom-nav shell (see app_router.dart / issue #67) — they
      // must stay gated the same way the old flat page map gated them.
      for (final path in [
        AppRoutes.mainApp,
        AppRoutes.explore,
        AppRoutes.activity,
        AppRoutes.profile,
      ]) {
        expect(
          AppRouter.isProtectedLocation(path),
          isTrue,
          reason: '$path should require a signed-in customer',
        );
      }
    });
  });

  group('password reset routes', () {
    test('reset password is a protected route', () {
      expect(AppRouter.isProtectedLocation(AppRoutes.resetPassword), isTrue);
    });

    test('forgot password is not a protected route', () {
      expect(AppRouter.isProtectedLocation(AppRoutes.forgotPassword), isFalse);
    });
  });

  group('route-string convention (issue #69)', () {
    test(
      'every ServiceDescriptor.entryRoute resolves to a registered route',
      () {
        for (final module in ServiceRegistry.modules) {
          expect(
            AppRouter.hasRegisteredRoute(module.entryRoute),
            isTrue,
            reason:
                '${module.id} entryRoute "${module.entryRoute}" has no '
                'matching GoRoute',
          );
        }
      },
    );

    test('every details_route the customer_activity SQL view can produce '
        'resolves to a registered route', () {
      // Mirrors the literal `details_route` values selected by the
      // `customer_activity` view as currently (re)defined in
      // supabase/migrations/20260815153920_remove_cleaning_vertical.sql
      // (food/grocery/pharmacy branches; the earlier cleaning branch from
      // 20260727152319_connect_super_app_services.sql was dropped by
      // issue #50 and no longer exists in the live view definition).
      // There is no SQL execution available from a Dart unit test, so
      // this list is a manually kept mirror of that view's `select`
      // branches — if a future migration changes, adds, or removes a
      // `details_route` literal in customer_activity, update this list to
      // match, in the same change.
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

    test('foodRestaurants is deliberately not a registered route (path-prefix '
        'only, see app_routes.dart)', () {
      expect(AppRouter.hasRegisteredRoute(AppRoutes.foodRestaurants), isFalse);
      // The parameterized route it is a prefix of IS registered.
      expect(AppRouter.hasRegisteredRoute(AppRoutes.foodRestaurant), isTrue);
    });

    test('pharmacyStores is deliberately not a registered route (path-prefix '
        'only, mirrors foodRestaurants, see app_routes.dart)', () {
      expect(AppRouter.hasRegisteredRoute(AppRoutes.pharmacyStores), isFalse);
      // The parameterized route it is a prefix of IS registered.
      expect(AppRouter.hasRegisteredRoute(AppRoutes.pharmacyStore), isTrue);
    });
  });

  group('pharmacy store routes (issue #141)', () {
    test('builds a pharmacy store details path', () {
      expect(
        AppRoutes.pharmacyStoreDetails('legacy-pharmacy'),
        '/pharmacy/stores/legacy-pharmacy',
      );
    });

    test('a pharmacy store details path requires a signed-in customer', () {
      final path = AppRoutes.pharmacyStoreDetails('legacy-pharmacy');
      expect(AppRouter.isProtectedLocation(path), isTrue);
      expect(
        AppRouter.resolveRedirect(
          isLoggedIn: false,
          isProtected: AppRouter.isProtectedLocation(path),
          location: path,
        ),
        AppRoutes.login,
      );
    });
  });

  group('track order routes (issue #43)', () {
    test('trackOrderDetails is a registered route', () {
      expect(AppRouter.hasRegisteredRoute(AppRoutes.trackOrderDetails), isTrue);
    });

    test('trackOrderDetailsPath builds a URL-encoded id/service path', () {
      expect(
        AppRoutes.trackOrderDetailsPath(
          serviceId: 'food',
          orderId: 'order 1/2',
        ),
        '/track-order/food/order%201%2F2',
      );
    });

    test('isTrackOrderDetails recognizes a built path but not the bare '
        'track-order route', () {
      expect(
        AppRoutes.isTrackOrderDetails(
          AppRoutes.trackOrderDetailsPath(
            serviceId: 'food',
            orderId: 'order-1',
          ),
        ),
        isTrue,
      );
      expect(AppRoutes.isTrackOrderDetails(AppRoutes.trackOrder), isFalse);
    });

    test('a built trackOrderDetails path requires a signed-in customer', () {
      final path = AppRoutes.trackOrderDetailsPath(
        serviceId: 'grocery',
        orderId: 'order-2',
      );
      expect(AppRouter.isProtectedLocation(path), isTrue);
      expect(
        AppRouter.resolveRedirect(
          isLoggedIn: false,
          isProtected: AppRouter.isProtectedLocation(path),
          location: path,
        ),
        AppRoutes.login,
      );
    });

    test('the bare track-order route also requires a signed-in customer', () {
      expect(AppRouter.isProtectedLocation(AppRoutes.trackOrder), isTrue);
    });
  });

  group('unknown routes (issue #40)', () {
    test('an unregistered path is not a registered route', () {
      expect(
        AppRouter.hasRegisteredRoute('/this-path-does-not-exist'),
        isFalse,
      );
    });
  });
}
