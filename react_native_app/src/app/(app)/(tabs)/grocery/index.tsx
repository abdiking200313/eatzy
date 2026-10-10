import { GroceryStoreListScreen } from '@/features/grocery/grocery-store-list-screen';

// Ports AppRoutes.grocery ('/grocery') from
// flutter_app/lib/services/grocery/presentation/grocery_screen.dart
// (issue #389 / P7-01).
export default function GroceryScreen() {
  return <GroceryStoreListScreen storeType="grocery" />;
}
