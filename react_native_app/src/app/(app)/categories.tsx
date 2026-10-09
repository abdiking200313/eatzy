import { Redirect } from 'expo-router';

// Legacy redirect, ported from app_router.dart's `_standaloneProtectedRoutes`
// (or the root GoRoute): AppRoutes.categories ('/categories') -> '/services'.
// Issue #358: route skeleton only.
export default function CategoriesLegacyRedirect() {
  return <Redirect href="/services" />;
}
