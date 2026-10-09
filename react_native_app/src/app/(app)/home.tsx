import { Redirect } from 'expo-router';

// Legacy redirect, ported from app_router.dart's `_standaloneProtectedRoutes`
// (or the root GoRoute): AppRoutes.home ('/home') -> '/app'.
// Issue #358: route skeleton only.
export default function HomeLegacyRedirect() {
  return <Redirect href="/app" />;
}
