/**
 * Ports `flutter_app/test/route_reachability_test.dart` (issue #71) to this
 * app's Expo Router tree, for the router-skeleton issue (#358).
 *
 * The Flutter test's actual mechanism is a source-grep: it asserts every
 * `AppRoutes` constant is either referenced by a real `context.push`/
 * `context.go` call site somewhere in `lib/`, or is explicitly documented in
 * `_deepLinkOnlyRoutes` with a reason it has none. That grep has no
 * meaningful RN equivalent *yet* — every screen under `src/app/` here is
 * still a trivial placeholder (issue #358's own scope) with no real
 * navigation call sites at all; the auth/role redirect gate and real screen
 * content (where in-app links will actually appear) land in #359/#360 and
 * later. So this file instead ports the Flutter test's *route table* and
 * *legacy-redirect destinations* — the part of its intent that already has
 * something to verify: every `AppRoutes` path from that table resolves to a
 * real screen in the new Expo Router tree, and every legacy-alias path
 * (`/`, `/home`, `/categories`, `/cart`, `/checkout`, `/restaurants`,
 * `/restaurants/:id`) redirects to the same destination the Flutter route
 * table documents. Once #359/#360 add real navigation, a follow-up issue can
 * port the "is it actually linked from somewhere" half of this test too.
 *
 * `renderRouter`/`screen` come from `expo-router/testing-library` (see
 * `src/test-utils/render-with-providers.tsx`'s doc comment on why that
 * helper itself does not wrap a route tree) — it renders the real
 * `src/app/**` routes against a given `initialUrl`.
 *
 * Two modules are mocked because this is the first test to mount the real
 * root `_layout.tsx`, which every route in this file goes through:
 *  - `@/components/animated-icon`'s `AnimatedSplashOverlay` (issue #353)
 *    pulls in `react-native-reanimated` + `react-native-worklets`; the
 *    latter's native module throws under Jest's Node environment
 *    ("Cannot read properties of undefined (reading 'loadUnpackers')"), and
 *    reanimated's own official Jest mock (`react-native-reanimated/mock`)
 *    doesn't fully stand in for it either in this reanimated v4 / worklets
 *    v0.x pairing (it still throws deeper inside, "createSerializable is not
 *    a function"). The splash overlay's own animation behavior is unrelated
 *    to routing, so a no-op stub here is a faithful enough stand-in, scoped
 *    to just this file rather than a project-wide jest.config.js change.
 *  - `@/platform/supabase/client`'s side-effecting import (issue #346) calls
 *    `loadEnv()` at module load, which throws `MissingEnvVarError` unless
 *    `EXPO_PUBLIC_SUPABASE_URL`/`EXPO_PUBLIC_SUPABASE_ANON_KEY` are set — not
 *    the case under `npm test`. No route test here exercises Supabase, so a
 *    stub is enough, but (since issue #359) it has to be a slightly more
 *    complete one than a bare `{}`: `src/stores/session-store.ts`'s
 *    app-wide singleton is constructed the moment the root `_layout.tsx` —
 *    and so every route in this file — is first rendered, and that
 *    construction calls `supabase.auth.onAuthStateChange(...)` eagerly. The
 *    stub below supplies a no-op `onAuthStateChange` that never actually
 *    calls back, so the session store's status stays `'loading'` for all of
 *    this file's cases — `(auth)/_layout.tsx` and `(app)/_layout.tsx` both
 *    render unguarded (no redirect) while `status === 'loading'` (see
 *    their own doc comments), which is exactly the pre-#359 behavior this
 *    file's assertions were already written against.
 *
 * Every `renderRouter(...)` call below is `await`ed before any assertion.
 * `@testing-library/react-native` v14's `render` is itself async (see
 * `render-with-providers.tsx`'s doc comment), and `expo-router/testing-
 * library`'s `renderRouter` (built against RNTL's older, synchronous
 * `render`) does not await it internally — skipping the `await` here left
 * the previous test's render still in flight (and un-registered for RNTL's
 * auto-cleanup) when the next test started, observable as "overlapping
 * act() calls" warnings and a route's pathname leaking into the next test.
 */
import { renderRouter, screen, waitFor } from 'expo-router/testing-library';

jest.mock('@/components/animated-icon', () => ({ AnimatedSplashOverlay: () => null }));
jest.mock('@/platform/supabase/client', () => ({
  supabase: {
    auth: {
      onAuthStateChange: () => ({ data: { subscription: { unsubscribe: () => {} } } }),
    },
  },
}));

/**
 * Renders `path` against the real `src/app/` route tree, settled, and
 * returns the render result wrapped in a plain object.
 *
 * The wrapper matters: `renderRouter`'s return value is itself a thenable
 * (RNTL v14's `render` promise, with `getPathname`/etc. `Object.assign`ed
 * directly onto it -- see this file's top comment). Returning that thenable
 * straight from an `async function` makes the *outer* function's own
 * Promise resolution unwrap it a second time via `.then()`, which discards
 * those extra properties and leaves a bare, prop-less value on the other
 * side of `await renderRoute(...)`. Returning `{ result }` (an ordinary,
 * non-thenable object) sidesteps that second unwrap.
 */
async function renderRoute(path: string) {
  const result = renderRouter('src/app', { initialUrl: path });
  await result;
  return { result };
}

describe('route reachability (ports route_reachability_test.dart, issue #71/#358)', () => {
  // Every non-parameterized `AppRoutes` path from the Flutter test's
  // `_registeredRoutes` list that isn't a legacy-redirect alias, paired with
  // the placeholder screen's exact rendered text (every placeholder screen
  // added by #358 renders "<path> — not yet implemented").
  //
  // `welcome` ('/welcome'), `login` ('/login'), and `register` ('/register')
  // are excluded from this table — issues #364, #365, and #366 respectively
  // gave them real content, so none of the three renders the generic
  // placeholder text any more. See `welcome.test.tsx`/`welcome-back-
  // navigation.test.tsx`, `src/app/(auth)/login.test.tsx`, and `src/app/
  // (auth)/register.test.tsx` for their own coverage, and the
  // `'AppRoutes.welcome/login/register ... resolves to its real screen'`
  // cases just below for this file's one directly-relevant check each (that
  // the route still resolves, now to the real screen).
  const staticRoutes: [name: string, path: string][] = [
    ['forgotPassword', '/forgot-password'],
    ['mainApp', '/app'],
    ['services', '/services'],
    ['explore', '/explore'],
    ['activity', '/activity'],
    ['profile', '/profile'],
    ['addresses', '/addresses'],
    ['settings', '/settings'],
    ['resetPassword', '/reset-password'],
    ['support', '/support'],
    ['trackOrder', '/track-order'],
    ['food', '/food'],
    ['foodCategories', '/food/categories'],
    ['foodExplore', '/food/explore'],
    ['foodCart', '/food/cart'],
    ['foodCheckout', '/food/checkout'],
    ['grocery', '/grocery'],
    ['groceryCart', '/grocery/cart'],
    ['groceryCheckout', '/grocery/checkout'],
    ['pharmacy', '/pharmacy'],
    ['pharmacyCart', '/pharmacy/cart'],
    ['pharmacyCheckout', '/pharmacy/checkout'],
  ];

  test.each(staticRoutes)('AppRoutes.%s (%s) resolves to its placeholder screen', async (_name, path) => {
    await renderRoute(path);
    expect(await screen.findByText(`${path} — not yet implemented`)).toBeTruthy();
  });

  // AppRoutes.welcome ('/welcome') resolves to its real screen since issue
  // #364 (see this describe block's top comment) rather than the generic
  // placeholder text every other static route above still renders.
  test('AppRoutes.welcome (/welcome) resolves to its real screen', async () => {
    await renderRoute('/welcome');
    expect(await screen.findByText("See What's Open Near You")).toBeTruthy();
  });

  // AppRoutes.login (/login) resolves to its real screen since issue #365,
  // same posture as the `welcome` case above.
  test('AppRoutes.login (/login) resolves to its real screen', async () => {
    await renderRoute('/login');
    expect(await screen.findByText('Welcome back')).toBeTruthy();
  });

  // AppRoutes.register (/register) resolves to its real screen since issue
  // #366, same posture as the `welcome`/`login` cases above.
  test('AppRoutes.register (/register) resolves to its real screen', async () => {
    await renderRoute('/register');
    expect(await screen.findByText('Create your account')).toBeTruthy();
  });

  // Parameterized `AppRoutes` paths, each visited at a concrete URL. The
  // placeholder screen renders the path *template* (with `:param` segments)
  // plus the actual param value(s) in parens.
  const dynamicRoutes: [name: string, template: string, concretePath: string, text: string][] = [
    [
      'foodRestaurant',
      '/food/restaurants/:restaurantId',
      '/food/restaurants/rest-1',
      '/food/restaurants/:restaurantId (rest-1) — not yet implemented',
    ],
    [
      'groceryStore',
      '/grocery/stores/:storeId',
      '/grocery/stores/store-1',
      '/grocery/stores/:storeId (store-1) — not yet implemented',
    ],
    [
      'trackOrderDetails',
      '/track-order/:serviceId/:orderId',
      '/track-order/food/order-1',
      '/track-order/:serviceId/:orderId (food order-1) — not yet implemented',
    ],
  ];

  test.each(dynamicRoutes)('AppRoutes.%s (%s) resolves to its placeholder screen', async (_name, _template, concretePath, text) => {
    await renderRoute(concretePath);
    expect(await screen.findByText(text)).toBeTruthy();
  });

  // Legacy-alias `AppRoutes` paths (route_reachability_test.dart's
  // `_deepLinkOnlyRoutes`, excluding `profile`/`addresses`/`trackOrder` —
  // those are real placeholder screens above, not redirects): each must
  // redirect to the same destination app_routes.dart documents.
  const legacyRedirects: [name: string, from: string, to: string][] = [
    ['root', '/', '/welcome'],
    ['home', '/home', '/app'],
    ['categories', '/categories', '/services'],
    ['cart', '/cart', '/food/cart'],
    ['checkout', '/checkout', '/food/checkout'],
    ['restaurants', '/restaurants', '/food'],
    ['restaurant', '/restaurants/rest-1', '/food/restaurants/rest-1'],
  ];

  test.each(legacyRedirects)('AppRoutes.%s (%s) redirects to %s', async (_name, from, to) => {
    const { result } = await renderRoute(from);
    // `expect(result).toHavePathname(to)` (the matcher expo-router/testing-
    // library actually registers, via expect.extend in its `./expect`
    // module) would read better, but that package ships no type
    // declaration for it -- `toHavePathname` isn't a known member of
    // `JestMatchers<Result>` under `tsc --noEmit`. Asserting the plain
    // `getPathname()` string (a properly typed member of `Result`, see
    // `renderRouter`'s own return type) checks the same thing without the
    // type error.
    await waitFor(() => expect(result.getPathname()).toBe(to));
  });
});
