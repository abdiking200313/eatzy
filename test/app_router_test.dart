import 'package:chowflow/app/app_router.dart';
import 'package:chowflow/app/app_routes.dart';
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

    test('sends a restored session away from onboarding', () {
      final redirect = AppRouter.resolveRedirect(
        isLoggedIn: true,
        isProtected: false,
        location: AppRoutes.onboardingTwo,
      );

      expect(redirect, AppRoutes.mainApp);
    });

    test('sends a signed-out user to login for protected routes', () {
      final redirect = AppRouter.resolveRedirect(
        isLoggedIn: false,
        isProtected: true,
        location: AppRoutes.orders,
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
}
