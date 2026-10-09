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
 * `hasSeenOnboarding` and `isMerchant` both default to `false` on
 * `ResolveRedirectOptions` only so every case in `app_router_test.dart`
 * (including the merchant ones) can be exercised directly against this
 * pure function, the same way Flutter's test calls
 * `AppRouter.resolveRedirect` with explicit booleans instead of a real
 * session/role lookup. Every real call site now supplies its own real
 * value instead of relying on that default: `hasSeenOnboarding` comes from
 * `src/stores/onboarding-store.ts` (issue #360); `isMerchant` comes from
 * `src/stores/merchant-session-gate.ts` (issue #363, porting Flutter's
 * `MerchantSessionGate`) via `(auth)/_layout.tsx`/`(app)/_layout.tsx`.
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
  /** Real value supplied by `src/stores/merchant-session-gate.ts` (issue #363) -- see this file's top comment. */
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
