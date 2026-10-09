import { Redirect } from 'expo-router';

// Legacy redirect, ported from app_router.dart's `_standaloneProtectedRoutes`
// (or the root GoRoute): AppRoutes.restaurants ('/restaurants') -> '/food'.
// Issue #358: route skeleton only.
export default function RestaurantsLegacyRedirect() {
  return <Redirect href="/food" />;
}
