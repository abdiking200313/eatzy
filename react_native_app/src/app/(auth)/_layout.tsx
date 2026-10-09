import { Redirect, Stack, useGlobalSearchParams, usePathname } from 'expo-router';

import { isProtectedLocation, isWelcomeRevisit, resolveRedirect } from '@/platform/navigation/redirect';
import { useMerchantSessionGateStore } from '@/stores/merchant-session-gate';
import { useOnboardingStore } from '@/stores/onboarding-store';
import { useSessionStore } from '@/stores/session-store';

// Public routes (no Supabase session required) -- mirrors app_router.dart's
// `_publicRoutes`, gated the way `AppRouter._redirect` gates them (issue
// #359): a signed-in user is bounced off every route in this group to
// `/app` (see `resolveRedirect`'s signed-out-only-routes check), a
// returning signed-out user (this device's persisted `hasSeenOnboarding`
// flag -- `onboarding-store.ts`, issue #360) is sent straight to `/login`
// instead of seeing `/welcome` again, and a signed-in `merchant`/`admin`
// account (`merchant-session-gate.ts`, issue #363) is sent to `/merchant`
// instead.
//
// `useSessionStore`'s `status` starts at `'loading'` while a persisted
// session is still being restored (async), and `useOnboardingStore`'s
// `status` starts at `'idle'`/`'loading'` while the persisted onboarding
// flag is still being read. This renders unguarded during that window
// rather than blocking, since the root `_layout.tsx`'s `useStartupGate`
// call (#360) is what holds the native splash screen over this exact gap
// in production. `merchantRolePending` below extends that same "render
// unguarded rather than decide on stale/incomplete data" treatment to the
// window after a signed-in user is known but their `profiles.role` lookup
// is still running -- otherwise a freshly signed-in merchant/admin would be
// redirected to `/app` by the signed-out-only-route rule before the role
// lookup resolves, then immediately redirected again to `/merchant`,
// flashing the customer home for a frame.
export default function AuthLayout() {
  const status = useSessionStore((state) => state.status);
  const userId = useSessionStore((state) => state.userId);
  const hasSeenOnboarding = useOnboardingStore((state) => state.hasSeenOnboarding);
  const merchantResolvedUserId = useMerchantSessionGateStore((state) => state.resolvedUserId);
  const isMerchantRole = useMerchantSessionGateStore((state) => state.isMerchantRole);
  const pathname = usePathname();
  const { revisit } = useGlobalSearchParams<{ revisit?: string | string[] }>();

  const merchantRolePending = userId != null && merchantResolvedUserId !== userId;

  if (status !== 'loading' && !merchantRolePending) {
    const redirectTo = resolveRedirect({
      isLoggedIn: userId != null,
      isProtected: isProtectedLocation(pathname),
      location: pathname,
      hasSeenOnboarding,
      revisitWelcome: isWelcomeRevisit(revisit),
      isMerchant: isMerchantRole,
    });

    if (redirectTo != null) {
      return <Redirect href={redirectTo} />;
    }
  }

  return <Stack screenOptions={{ headerShown: false }} />;
}
