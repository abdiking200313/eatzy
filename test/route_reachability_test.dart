// Issue #71: "Twelve registered routes and ~600 lines of feature UI are
// unreachable from anywhere in the app". This test asserts every path
// registered in AppRouter is either linked from somewhere in lib/ (a real
// context.push/context.go call site, or the literal path string) or is
// explicitly documented below as intentionally deep-link-only, with a
// reason. If you register a new route, either wire up a real entry point or
// add it to `_deepLinkOnlyRoutes` with a reason -- don't let it go silently
// unreachable again.
import 'dart:io';

import 'package:chowflow/app/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registered route path -> why it intentionally has no in-app
/// context.push/context.go call site.
final Map<String, String> _deepLinkOnlyRoutes = {
  // Index route: AppRouter's own redirect sends it straight to `welcome`.
  // The app itself never navigates here on purpose.
  AppRoutes.root: 'index route, always redirected to welcome by AppRouter',

  // Reached only via AppRouter's own `initialLocation` and the `/` redirect
  // above -- both internal to AppRouter itself. The app never explicitly
  // navigates back to welcome (logout goes to /login, not here).
  AppRoutes.welcome:
      'reached only via AppRouter.initialLocation / the root redirect',

  // The onboarding slides are rendered as PageView children embedded
  // directly inside WelcomeScreen (see welcome_screen.dart) rather than
  // being pushed through the router. Found incidentally while building this
  // exhaustive check for #71 -- left as-is rather than expanding #71's scope
  // into the onboarding flow.
  AppRoutes.onboardingOne: 'shown as a PageView child inside WelcomeScreen',
  AppRoutes.onboardingTwo: 'shown as a PageView child inside WelcomeScreen',
  AppRoutes.onboardingThree: 'shown as a PageView child inside WelcomeScreen',

  // Legacy redirect aliases, kept for backward-compat / old deep links.
  // Issue #71 decision: keep these; a route existing only for old links is a
  // normal reason for it to have no in-app link.
  AppRoutes.home: 'legacy alias, redirects to ${AppRoutes.mainApp}',
  AppRoutes.categories: 'legacy alias, redirects to ${AppRoutes.services}',
  AppRoutes.cart: 'legacy alias, redirects to ${AppRoutes.foodCart}',
  AppRoutes.checkout: 'legacy alias, redirects to ${AppRoutes.foodCheckout}',
  AppRoutes.restaurants: 'legacy alias, redirects to ${AppRoutes.food}',
  AppRoutes.restaurant: 'legacy alias, redirects to a restaurant details path',

  // Standalone screen also reachable as a bottom-nav tab inside
  // MainAppScreen (an IndexedStack swap, not a router push) -- the path
  // itself has no in-app link, kept for direct/web URL access. ExploreScreen
  // also renders the identical ServiceRegistry.modules list CategoriesScreen
  // does, in a different card style -- flagged for a future human
  // consolidation decision, not resolved by issue #71.
  AppRoutes.explore:
      'reachable as the Explore bottom-nav tab, not a route push',
  AppRoutes.profile:
      'reachable as the Profile bottom-nav tab, not a route push',

  // The bare (no id/service) form is kept only for backward compatibility
  // with an old deep link that has no order to point at -- TrackOrderScreen
  // renders a "no order selected" empty state for it. The real, reachable
  // form is the parameterized `trackOrderDetails` route below, linked from
  // the "Track order" action on an ActivityScreen row (issue #43).
  AppRoutes.trackOrder:
      'kept only for old deep links with no order id; see trackOrderDetails '
      'for the real reachable route (#43)',
};

/// Every path AppRouter registers, as (constant name, path value) so
/// failures point straight at the AppRoutes constant to fix.
final List<({String name, String path})> _registeredRoutes = [
  (name: 'root', path: AppRoutes.root),
  (name: 'welcome', path: AppRoutes.welcome),
  (name: 'login', path: AppRoutes.login),
  (name: 'register', path: AppRoutes.register),
  (name: 'forgotPassword', path: AppRoutes.forgotPassword),
  (name: 'onboardingOne', path: AppRoutes.onboardingOne),
  (name: 'onboardingTwo', path: AppRoutes.onboardingTwo),
  (name: 'onboardingThree', path: AppRoutes.onboardingThree),
  (name: 'mainApp', path: AppRoutes.mainApp),
  (name: 'services', path: AppRoutes.services),
  (name: 'explore', path: AppRoutes.explore),
  (name: 'activity', path: AppRoutes.activity),
  (name: 'profile', path: AppRoutes.profile),
  (name: 'addresses', path: AppRoutes.addresses),
  (name: 'paymentMethods', path: AppRoutes.paymentMethods),
  (name: 'settings', path: AppRoutes.settings),
  (name: 'resetPassword', path: AppRoutes.resetPassword),
  (name: 'support', path: AppRoutes.support),
  (name: 'wallet', path: AppRoutes.wallet),
  (name: 'trackOrder', path: AppRoutes.trackOrder),
  (name: 'trackOrderDetails', path: AppRoutes.trackOrderDetails),
  (name: 'rewards', path: AppRoutes.rewards),
  (name: 'rewardsProfile', path: AppRoutes.rewardsProfile),
  (name: 'food', path: AppRoutes.food),
  (name: 'foodCategories', path: AppRoutes.foodCategories),
  (name: 'foodExplore', path: AppRoutes.foodExplore),
  (name: 'foodCart', path: AppRoutes.foodCart),
  (name: 'foodCheckout', path: AppRoutes.foodCheckout),
  (name: 'grocery', path: AppRoutes.grocery),
  (name: 'groceryCart', path: AppRoutes.groceryCart),
  (name: 'groceryCheckout', path: AppRoutes.groceryCheckout),
  (name: 'pharmacy', path: AppRoutes.pharmacy),
  (name: 'pharmacyCart', path: AppRoutes.pharmacyCart),
  (name: 'pharmacyCheckout', path: AppRoutes.pharmacyCheckout),
  (name: 'foodRestaurant', path: AppRoutes.foodRestaurant),
  (name: 'home', path: AppRoutes.home),
  (name: 'categories', path: AppRoutes.categories),
  (name: 'cart', path: AppRoutes.cart),
  (name: 'checkout', path: AppRoutes.checkout),
  (name: 'restaurants', path: AppRoutes.restaurants),
  (name: 'restaurant', path: AppRoutes.restaurant),
];

void main() {
  // All lib/ source, excluding the two files that *register* routes -- we
  // want evidence of *usage* elsewhere, not just the registration itself.
  late String combinedSource;

  setUpAll(() {
    final sourceFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where(
          (file) =>
              !file.path.endsWith('app_router.dart') &&
              !file.path.endsWith('app_routes.dart'),
        );
    combinedSource = sourceFiles.map((f) => f.readAsStringSync()).join('\n');
  });

  bool isLinked(String name, String path) {
    // `AppRoutes.<name>` as a call-site token, e.g. `context.push(AppRoutes.wallet)`
    // or as a ProfileOption's `route:` value. The negative lookahead keeps
    // `AppRoutes.food` from matching inside `AppRoutes.foodCart`, and
    // `AppRoutes.restaurant` from matching inside `AppRoutes.restaurants`.
    if (RegExp('AppRoutes\\.$name(?![A-Za-z0-9_])').hasMatch(combinedSource)) {
      return true;
    }
    // Some call sites push a raw literal path instead of the constant
    // (e.g. grocery/pharmacy screens use `context.push('/grocery/cart')`).
    if (combinedSource.contains("'$path'") ||
        combinedSource.contains('"$path"')) {
      return true;
    }
    // The restaurant-details route is never navigated to via its raw
    // template path or the bare AppRoutes.foodRestaurant constant --
    // callers build a concrete path via AppRoutes.restaurantDetails(id).
    if (name == 'foodRestaurant' &&
        combinedSource.contains('restaurantDetails(')) {
      return true;
    }
    // Same pattern as foodRestaurant/restaurantDetails above: no call site
    // pushes the raw `trackOrderDetails` template path -- callers build a
    // concrete path via AppRoutes.trackOrderDetailsPath(...).
    if (name == 'trackOrderDetails' &&
        combinedSource.contains('trackOrderDetailsPath(')) {
      return true;
    }
    return false;
  }

  test(
    'every registered route is reachable from the app or documented as deep-link-only',
    () {
      for (final route in _registeredRoutes) {
        final reachable =
            isLinked(route.name, route.path) ||
            _deepLinkOnlyRoutes.containsKey(route.path);
        expect(
          reachable,
          isTrue,
          reason:
              'AppRoutes.${route.name} (${route.path}) has no '
              'context.push/context.go call site anywhere in lib/, and is '
              'not documented in _deepLinkOnlyRoutes. Add a real entry '
              'point, or document why it is intentionally unreachable '
              '(see issue #71).',
        );
      }
    },
  );

  test('routes documented as deep-link-only really have no in-app link', () {
    for (final entry in _deepLinkOnlyRoutes.entries) {
      final route = _registeredRoutes.firstWhere(
        (route) => route.path == entry.key,
        orElse: () => throw StateError(
          '${entry.key} is in _deepLinkOnlyRoutes but is not a registered '
          'route in _registeredRoutes -- fix the route list above.',
        ),
      );
      expect(
        isLinked(route.name, route.path),
        isFalse,
        reason:
            'AppRoutes.${route.name} (${route.path}) is documented as '
            'deep-link-only but now has an in-app link -- remove the stale '
            'entry from _deepLinkOnlyRoutes.',
      );
    }
  });
}
