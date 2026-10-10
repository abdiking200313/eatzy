import { useLocalSearchParams } from 'expo-router';

import { GroceryStoreScreen } from '@/features/grocery/grocery-store-screen';

// Ports AppRoutes.freshMeatStore ('/grocery/fresh-meat/stores/:storeId') from
// flutter_app/lib/services/grocery/presentation/grocery_store_screen.dart
// (issue #390 / P7-02).
export default function FreshMeatStoreRoute() {
  const { storeId } = useLocalSearchParams<{ storeId: string }>();
  return <GroceryStoreScreen storeId={storeId} storeType="fresh_meat" />;
}
