import { Redirect, Stack, useGlobalSearchParams, usePathname } from 'expo-router';

import { isProtectedLocation, isWelcomeRevisit, resolveRedirect } from '@/platform/navigation/redirect';
import { useSessionStore } from '@/stores/session-store';

// Public routes (no Supabase session required) -- mirrors app_router.dart's
// `_publicRoutes`, gated the way `AppRouter._redirect` gates them (issue
// #359): a signed-in user is bounced off every route in this group to
// `/app` (see `resolveRedirect`'s signed-out-only-routes check), and a
// returning signed-out user would be sent straight to `/login` instead of
// seeing `/welcome` again -- once #360 (startup gate) supplies the
// persisted `hasSeenOnboarding` flag `resolveRedirect` reads for that; it
// defaults to `false` here until then, so nobody is skipped past welcome
// yet. The merchant-role detour (#363) isn't wired in either -- see
// `redirect.ts`'s top comment for both.
//
// `useSessionStore`'s `status` starts at `'loading'` while a persisted
// session is still being restored (async). This renders unguarded during
// that window rather than blocking, since #360 is what holds the native
// splash screen over this exact gap in production.
export default function AuthLayout() {
  const status = useSessionStore((state) => state.status);
  const userId = useSessionStore((state) => state.userId);
  const pathname = usePathname();
  const { revisit } = useGlobalSearchParams<{ revisit?: string | string[] }>();

  if (status !== 'loading') {
    const redirectTo = resolveRedirect({
      isLoggedIn: userId != null,
      isProtected: isProtectedLocation(pathname),
      location: pathname,
      revisitWelcome: isWelcomeRevisit(revisit),
    });

    if (redirectTo != null) {
      return <Redirect href={redirectTo} />;
    }
  }

  return <Stack screenOptions={{ headerShown: false }} />;
}
