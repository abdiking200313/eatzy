import { Stack } from 'expo-router';

// Public routes (no Supabase session required) -- mirrors app_router.dart's `_publicRoutes`.
export default function AuthLayout() {
  return <Stack screenOptions={{ headerShown: false }} />;
}
