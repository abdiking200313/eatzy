import { GroceryStoreListScreen } from '@/features/grocery/grocery-store-list-screen';

// Ports AppRoutes.freshMeat ('/grocery/fresh-meat') from
// flutter_app/lib/services/grocery/presentation/grocery_screen.dart
// (issue #389 / P7-01). Fresh Meat runs on the grocery engine, filtered to
// its own store type -- see grocery-store-type-meta.ts.
export default function FreshMeatScreen() {
  return <GroceryStoreListScreen storeType="fresh_meat" />;
}
