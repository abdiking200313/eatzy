import { Stack } from 'expo-router';

// Standalone merchant dashboard (issue #232/#236), outside the customer (app) shell -- mirrors app_router.dart's `MerchantShell` + its merchant-session gating (ported in a later issue).
export default function MerchantLayout() {
  return <Stack screenOptions={{ headerShown: false }} />;
}
