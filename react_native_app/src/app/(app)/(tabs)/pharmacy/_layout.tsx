import { Stack } from 'expo-router';

// Pharmacy vertical branch of the shell -- mirrors app_router.dart's pharmacy StatefulShellBranch.
export default function PharmacyLayout() {
  return <Stack screenOptions={{ headerShown: false }} />;
}
