import { Redirect, Stack, useGlobalSearchParams, usePathname } from 'expo-router';

import { isProtectedLocation, isWelcomeRevisit, resolveRedirect } from '@/platform/navigation/redirect';
import { useOnboardingStore } from '@/stores/onboarding-store';
import { useSessionStore } from '@/stores/session-store';

// Public routes (no Supabase session required) -- mirrors app_router.dart's
// `_publicRoutes`, gated the way `AppRouter._redirect` gates them (issue
// #359): a signed-in user is bounced off every route in this group to
// `/app` (see `resolveRedirect`'s signed-out-only-routes check), and a
// returning signed-out user (this device's persisted `hasSeenOnboarding`
// flag -- `onboarding-store.ts`, issue #360) is sent straight to `/login`
// instead of seeing `/welcome` again. The merchant-role detour (#363) isn't
// wired in yet -- see `redirect.ts`'s top comment.
//
// `useSessionStore`'s `status` starts at `'loading'` while a persisted
// session is still being restored (async), and `useOnboardingStore`'s
// `status` starts at `'idle'`/`'loading'` while the persisted onboarding
// flag is still being read. This renders unguarded during that window
// rather than blocking, since the root `_layout.tsx`'s `useStartupGate`
// call (#360) is what holds the native splash screen over this exact gap
// in production.
export default function AuthLayout() {
  const status = useSessionStore((state) => state.status);
  const userId = useSessionStore((state) => state.userId);
  const hasSeenOnboarding = useOnboardingStore((state) => state.hasSeenOnboarding);
  const pathname = usePathname();
  const { revisit } = useGlobalSearchParams<{ revisit?: string | string[] }>();

  if (status !== 'loading') {
    const redirectTo = resolveRedirect({
      isLoggedIn: userId != null,
      isProtected: isProtectedLocation(pathname),
      location: pathname,
      hasSeenOnboarding,
      revisitWelcome: isWelcomeRevisit(revisit),
    });

    if (redirectTo != null) {
      return <Redirect href={redirectTo} />;
    }
  }

  return <Stack screenOptions={{ headerShown: false }} />;
}
