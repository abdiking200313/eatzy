/**
 * Ports `AppRouter.resolveRedirect`/`AppRouter.isWelcomeRevisit` from
 * `flutter_app/lib/app/app_router.dart`'s `_redirect` logic (issue #359).
 *
 * This is deliberately a plain, synchronous function of its inputs -- the
 * same shape Flutter's own `resolveRedirect` takes, and the same shape
 * `app_router_test.dart` exercises it with -- rather than something that
 * reads the session store or a route object itself. `src/app/(auth)/
 * _layout.tsx` and `src/app/(app)/_layout.tsx` are what supply the real
 * inputs (session store state, `usePathname()`, the `revisit` query param).
 *
 * One of `resolveRedirect`'s Flutter inputs is still hard-coded to its
 * "nothing special happening yet" default at every call site in this app,
 * pending a later issue that supplies the real value:
 *  - `isMerchant` (always `false` here) -- Flutter's `MerchantSessionGate`
 *    (a `profiles.role` lookup) has no RN port yet; that lands in #363
 *    (merchant session gate). Until then every signed-in account is routed
 *    as a customer, which is already every account that exists in this
 *    app's RN build.
 * `hasSeenOnboarding` *was* hard-coded to `false` the same way until #360
 * (startup gate), which ports Flutter's `OnboardingLaunchGate` as
 * `src/stores/onboarding-store.ts` and now passes its real
 * `hasSeenOnboarding` value from `(auth)/_layout.tsx`/`(app)/_layout.tsx`.
 * Both parameters stay on `resolveRedirect` itself (rather than being
 * dropped once wired) so this function's own behavior can be exercised
 * against every case in `app_router_test.dart`, including the merchant
 * ones, the same way Flutter's test calls `AppRouter.resolveRedirect`
 * directly with explicit booleans instead of a real session/role lookup.
 */
import { AppRoutes, isProtectedLocation } from './app-routes';

export { isProtectedLocation };

// Mirrors `AppRouter._signedOutOnlyRoutes`.
const SIGNED_OUT_ONLY_ROUTES = new Set<string>([
  AppRoutes.welcome,
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.forgotPassword,
]);

/** Mirrors `AppRouter._isMerchantReachableLocation`. */
function isMerchantReachableLocation(location: string): boolean {
  return (
    location === AppRoutes.merchantDashboard ||
    location.startsWith(`${AppRoutes.merchantDashboard}/`) ||
    location === AppRoutes.resetPassword
  );
}

export interface ResolveRedirectOptions {
  isLoggedIn: boolean;
  isProtected: boolean;
  location: string;
  /** Real value supplied by `src/stores/onboarding-store.ts` (issue #360) -- see this file's top comment. */
  hasSeenOnboarding?: boolean;
  /** True for `AppRoutes.welcomeRevisit`'s `?revisit=true` -- see {@link isWelcomeRevisit}. */
  revisitWelcome?: boolean;
  /** See this file's top comment -- always `false` at every real call site until #363 lands. */
  isMerchant?: boolean;
}

/**
 * Ports `AppRouter.resolveRedirect`. Returns the path to redirect to, or
 * `null` to stay on `location`.
 */
export function resolveRedirect({
  isLoggedIn,
  isProtected,
  location,
  hasSeenOnboarding = false,
  revisitWelcome = false,
  isMerchant = false,
}: ResolveRedirectOptions): string | null {
  if (!isLoggedIn && isProtected) {
    return AppRoutes.login;
  }

  // A signed-in merchant/admin account is confined to `/merchant` (and any
  // sub-path under it) for the entire session -- every other location
  // sends it back to the merchant dashboard instead. `/reset-password` is
  // exempted (see `isMerchantReachableLocation`'s doc comment on the
  // Flutter side for why).
  if (isLoggedIn && isMerchant && !isMerchantReachableLocation(location)) {
    return AppRoutes.merchantDashboard;
  }

  if (isLoggedIn && SIGNED_OUT_ONLY_ROUTES.has(location)) {
    return AppRoutes.mainApp;
  }

  // A returning signed-out user (this device already finished or skipped
  // onboarding at least once) skips straight past the welcome/onboarding
  // slides on this and every later launch, landing on login instead of
  // seeing the first-launch sequence again.
  if (
    !isLoggedIn &&
    hasSeenOnboarding &&
    !revisitWelcome &&
    location === AppRoutes.welcome
  ) {
    return AppRoutes.login;
  }

  return null;
}

/**
 * Ports `AppRouter.isWelcomeRevisit`: true when the `revisit` query param
 * on `/welcome` is the literal string `'true'`. Expo Router's
 * `useGlobalSearchParams`/`useLocalSearchParams` can return a string or a
 * string array for a repeated query param; only a single literal `'true'`
 * (the only value this app ever sets) counts.
 */
export function isWelcomeRevisit(revisitParam: string | string[] | undefined): boolean {
  return (Array.isArray(revisitParam) ? revisitParam[0] : revisitParam) === 'true';
}
