import { Stack } from 'expo-router';

// Food vertical branch of the shell -- mirrors app_router.dart's food StatefulShellBranch.
export default function FoodLayout() {
  return <Stack screenOptions={{ headerShown: false }} />;
}
