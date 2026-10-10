import { useLocalSearchParams } from 'expo-router';

import { GroceryStoreScreen } from '@/features/grocery/grocery-store-screen';

// Ports AppRoutes.groceryStore ('/grocery/stores/:storeId') from
// flutter_app/lib/services/grocery/presentation/grocery_store_screen.dart
// (issue #390 / P7-02).
export default function GroceryStoreRoute() {
  const { storeId } = useLocalSearchParams<{ storeId: string }>();
  return <GroceryStoreScreen storeId={storeId} storeType="grocery" />;
}
