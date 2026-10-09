import { Redirect } from 'expo-router';

// Mirrors the root GoRoute in app_router.dart: AppRoutes.root ('/') always
// redirects to AppRoutes.welcome, unconditionally -- the app itself never
// navigates to '/' on purpose (see route_reachability_test.dart's
// `_deepLinkOnlyRoutes` entry for `root`). Issue #358.
export default function RootIndexRedirect() {
  return <Redirect href="/welcome" />;
}
