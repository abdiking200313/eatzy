import { Stack } from 'expo-router';

// Grocery-engine vertical branch of the shell. Grocery, Fresh Meat, and Electronics each keep their own store/cart/checkout family (owner decision, 2026-09-25) -- mirrors app_router.dart's `_groceryRoutes(GroceryStoreType)`.
export default function GroceryLayout() {
  return <Stack screenOptions={{ headerShown: false }} />;
}
