import { Redirect, Stack, usePathname } from 'expo-router';

import { isProtectedLocation, resolveRedirect } from '@/platform/navigation/redirect';
import { useSessionStore } from '@/stores/session-store';

// Authenticated shell -- mirrors app_router.dart's `_shellRoute` +
// `_standaloneProtectedRoutes`, gated the way `AppRouter._redirect` gates
// them (issue #359). Contains the (tabs) bottom-nav group plus the
// standalone protected screens and legacy redirect aliases. Every route in
// this group is a protected location (see `isProtectedLocation`), so in
// practice the only rule that fires here is "no session -> `/login`"; the
// merchant-role detour (#363) isn't wired in yet -- see `redirect.ts`'s top
// comment.
//
// See `(auth)/_layout.tsx`'s doc comment for why `status === 'loading'`
// renders unguarded instead of blocking.
export default function AppLayout() {
  const status = useSessionStore((state) => state.status);
  const userId = useSessionStore((state) => state.userId);
  const pathname = usePathname();

  if (status !== 'loading') {
    const redirectTo = resolveRedirect({
      isLoggedIn: userId != null,
      isProtected: isProtectedLocation(pathname),
      location: pathname,
    });

    if (redirectTo != null) {
      return <Redirect href={redirectTo} />;
    }
  }

  return <Stack screenOptions={{ headerShown: false }} />;
}
