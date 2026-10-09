/**
 * Ports `flutter_app/test/app_router_test.dart`'s `AppRouter.resolveRedirect`
 * and `isProtectedLocation` groups (issue #359). See `redirect.ts`'s top
 * comment for why `hasSeenOnboarding`/`isMerchant` are still exercised here
 * even though every real call site in this app hard-codes them to `false`
 * today.
 */
import {
  groceryStoreDetails,
  isGroceryStoreDetails,
  isRestaurantDetails,
  isTrackOrderDetails,
  pharmacyStoreDetails,
  restaurantDetails,
  trackOrderDetailsPath,
} from './app-routes';
import { isProtectedLocation, isWelcomeRevisit, resolveRedirect } from './redirect';

interface RedirectCase {
  why: string;
  location: string;
  loggedIn?: boolean;
  merchant?: boolean;
  seenOnboarding?: boolean;
  revisit?: boolean;
  expected: string | null;
}

describe('resolveRedirect', () => {
  const merchantDashboardSubPath = '/merchant/orders';

  const cases: RedirectCase[] = [
    // Signed-in customers.
    {
      why: 'a restored session is sent from welcome to the app',
      location: '/welcome',
      loggedIn: true,
      expected: '/app',
    },
    {
      why: 'a restored session is sent away from register',
      location: '/register',
      loggedIn: true,
      expected: '/app',
    },
    {
      why: 'a logged-in user is sent away from forgot password',
      location: '/forgot-password',
      loggedIn: true,
      expected: '/app',
    },
    {
      why: 'a logged-in user (recovery or normal session) can reset password',
      location: '/reset-password',
      loggedIn: true,
      expected: null,
    },
    // Signed-out visitors.
    {
      why: 'a signed-out user is sent to login for protected routes',
      location: '/support',
      expected: '/login',
    },
    {
      why: 'a signed-out user may reach forgot password',
      location: '/forgot-password',
      expected: null,
    },
    {
      why: 'a signed-out user is sent to login for reset password',
      location: '/reset-password',
      expected: '/login',
    },
    {
      why: 'a signed-out visitor is sent to login, not the merchant dashboard',
      location: '/merchant',
      expected: '/login',
    },
    // Onboarding first-launch gating.
    {
      why: 'a first-time signed-out visitor stays on welcome',
      location: '/welcome',
      expected: null,
    },
    {
      why: 'a returning signed-out user goes from welcome straight to login',
      location: '/welcome',
      seenOnboarding: true,
      expected: '/login',
    },
    {
      why:
        'a returning signed-out user can reopen welcome on purpose (the back ' +
        'button on login/register)',
      location: '/welcome',
      seenOnboarding: true,
      revisit: true,
      expected: null,
    },
    {
      why: 'a signed-in user is sent to the app even with the revisit flag',
      location: '/welcome',
      loggedIn: true,
      seenOnboarding: true,
      revisit: true,
      expected: '/app',
    },
    {
      why: 'a returning signed-out user is not diverted away from login',
      location: '/login',
      seenOnboarding: true,
      expected: null,
    },
    {
      why: 'a returning but signed-in user goes to the app, not login',
      location: '/welcome',
      loggedIn: true,
      seenOnboarding: true,
      expected: '/app',
    },
    // Merchant dashboard routing.
    {
      why: 'a merchant/admin restored on welcome lands on the merchant dashboard',
      location: '/welcome',
      loggedIn: true,
      merchant: true,
      expected: '/merchant',
    },
    {
      why: 'a merchant/admin is redirected away from login',
      location: '/login',
      loggedIn: true,
      merchant: true,
      expected: '/merchant',
    },
    {
      why: 'a merchant/admin can stay on the merchant dashboard',
      location: '/merchant',
      loggedIn: true,
      merchant: true,
      expected: null,
    },
    {
      why: 'a merchant/admin can stay on a merchant dashboard sub-path',
      location: merchantDashboardSubPath,
      loggedIn: true,
      merchant: true,
      expected: null,
    },
    {
      why:
        'a merchant/admin can still complete a password reset (recovery-session ' +
        'exemption)',
      location: '/reset-password',
      loggedIn: true,
      merchant: true,
      expected: null,
    },
  ];

  test.each(cases)('$why', ({ location, loggedIn = false, merchant = false, seenOnboarding = false, revisit = false, expected }) => {
    expect(
      resolveRedirect({
        isLoggedIn: loggedIn,
        isProtected: isProtectedLocation(location),
        location,
        isMerchant: merchant,
        hasSeenOnboarding: seenOnboarding,
        revisitWelcome: revisit,
      }),
    ).toBe(expected);
  });

  const customerRoutes = [
    '/app',
    '/food',
    '/settings',
    '/support',
    '/grocery',
    '/pharmacy',
    '/profile',
    '/track-order',
    '/food/checkout',
  ];

  test('a merchant/admin is blocked from every customer route (#236), while a customer session reaches all of them', () => {
    for (const location of customerRoutes) {
      const redirectFor = (merchant: boolean) =>
        resolveRedirect({
          isLoggedIn: true,
          isProtected: isProtectedLocation(location),
          location,
          isMerchant: merchant,
        });

      expect(redirectFor(true)).toBe('/merchant');
      expect(redirectFor(false)).toBeNull();
    }
  });
});

test('isProtectedLocation gates every customer, service and merchant route, but not the pre-sign-in auth routes', () => {
  const protectedPaths = [
    '/app',
    '/explore',
    '/activity',
    '/profile',
    '/food',
    '/grocery/cart',
    '/pharmacy/checkout',
    groceryStoreDetails('bakaal-fresh'),
    pharmacyStoreDetails('legacy-pharmacy'),
    '/track-order',
    trackOrderDetailsPath({ serviceId: 'grocery', orderId: 'o-2' }),
    '/support',
    '/reset-password',
    '/merchant',
  ];
  for (const path of protectedPaths) {
    expect(isProtectedLocation(path)).toBe(true);
  }

  for (const path of ['/welcome', '/login', '/register', '/forgot-password']) {
    expect(isProtectedLocation(path)).toBe(false);
  }
});

test('path builders and predicates', () => {
  expect(restaurantDetails('restaurant-123')).toBe('/food/restaurants/restaurant-123');
  expect(isRestaurantDetails('/restaurants/r-1')).toBe(true);
  expect(isRestaurantDetails('/food/restaurants/r-1')).toBe(true);
  expect(isRestaurantDetails('/restaurants')).toBe(false);

  expect(groceryStoreDetails('bakaal-fresh')).toBe('/grocery/stores/bakaal-fresh');
  expect(isGroceryStoreDetails('/grocery/stores/bakaal-fresh')).toBe(true);
  expect(isGroceryStoreDetails('/grocery/cart')).toBe(false);
  expect(isGroceryStoreDetails('/grocery')).toBe(false);

  expect(pharmacyStoreDetails('legacy-pharmacy')).toBe('/pharmacy/stores/legacy-pharmacy');

  const trackPath = trackOrderDetailsPath({ serviceId: 'food', orderId: 'order 1/2' });
  expect(trackPath).toBe('/track-order/food/order%201%2F2');
  expect(isTrackOrderDetails(trackPath)).toBe(true);
  expect(isTrackOrderDetails('/track-order')).toBe(false);

  expect(isWelcomeRevisit('true')).toBe(true);
  expect(isWelcomeRevisit(undefined)).toBe(false);
  expect(isWelcomeRevisit('no')).toBe(false);
  expect(isWelcomeRevisit(['true', 'false'])).toBe(true);
});
