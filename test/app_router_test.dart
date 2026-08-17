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
}
