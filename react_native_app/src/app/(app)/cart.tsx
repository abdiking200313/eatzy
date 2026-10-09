import { Redirect } from 'expo-router';

// Legacy redirect, ported from app_router.dart's `_standaloneProtectedRoutes`
// (or the root GoRoute): AppRoutes.cart ('/cart') -> '/food/cart'.
// Issue #358: route skeleton only.
export default function CartLegacyRedirect() {
  return <Redirect href="/food/cart" />;
}
