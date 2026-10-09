import { Redirect, Stack, usePathname } from 'expo-router';

import { isProtectedLocation, resolveRedirect } from '@/platform/navigation/redirect';
import { useMerchantSessionGateStore } from '@/stores/merchant-session-gate';
import { useOnboardingStore } from '@/stores/onboarding-store';
import { useSessionStore } from '@/stores/session-store';

// Authenticated shell -- mirrors app_router.dart's `_shellRoute` +
// `_standaloneProtectedRoutes`, gated the way `AppRouter._redirect` gates
// them (issue #359). Contains the (tabs) bottom-nav group plus the
// standalone protected screens and legacy redirect aliases. Every route in
// this group is a protected location (see `isProtectedLocation`), so the
// rules that actually fire here are "no session -> `/login`" and "a
// `merchant`/`admin` account (`merchant-session-gate.ts`, issue #363) ->
// `/merchant`"; `hasSeenOnboarding` (issue #360) is passed through for the
// same reason Flutter's single `resolveRedirect` call reads
// `OnboardingLaunchGate` at every call site, even though no rule in this
// group's routes currently depends on it.
//
// See `(auth)/_layout.tsx`'s doc comment for why `status === 'loading'`
// renders unguarded instead of blocking, and for `merchantRolePending`
// below, which extends that same treatment to a signed-in user whose
// `profiles.role` lookup hasn't resolved yet.
export default function AppLayout() {
  const status = useSessionStore((state) => state.status);
  const userId = useSessionStore((state) => state.userId);
  const hasSeenOnboarding = useOnboardingStore((state) => state.hasSeenOnboarding);
  const merchantResolvedUserId = useMerchantSessionGateStore((state) => state.resolvedUserId);
  const isMerchantRole = useMerchantSessionGateStore((state) => state.isMerchantRole);
  const pathname = usePathname();

  const merchantRolePending = userId != null && merchantResolvedUserId !== userId;

  if (status !== 'loading' && !merchantRolePending) {
    const redirectTo = resolveRedirect({
      isLoggedIn: userId != null,
      isProtected: isProtectedLocation(pathname),
      location: pathname,
      hasSeenOnboarding,
      isMerchant: isMerchantRole,
    });

    if (redirectTo != null) {
      return <Redirect href={redirectTo} />;
    }
  }

  return <Stack screenOptions={{ headerShown: false }} />;
}
