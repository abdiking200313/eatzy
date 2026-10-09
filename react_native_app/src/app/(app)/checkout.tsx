import { Redirect } from 'expo-router';

// Legacy redirect, ported from app_router.dart's `_standaloneProtectedRoutes`
// (or the root GoRoute): AppRoutes.checkout ('/checkout') -> '/food/checkout'.
// Issue #358: route skeleton only.
export default function CheckoutLegacyRedirect() {
  return <Redirect href="/food/checkout" />;
}
