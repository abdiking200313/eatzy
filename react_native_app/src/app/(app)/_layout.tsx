import { Stack } from 'expo-router';

// Authenticated shell (issue #359/#360 adds the login-required redirect gate). Contains the (tabs) bottom-nav group plus the standalone protected screens and legacy redirect aliases -- mirrors app_router.dart's `_shellRoute` + `_standaloneProtectedRoutes`.
export default function AppLayout() {
  return <Stack screenOptions={{ headerShown: false }} />;
}
