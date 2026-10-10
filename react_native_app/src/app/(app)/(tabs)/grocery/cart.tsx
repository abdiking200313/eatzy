import { GroceryCartScreen } from '@/features/grocery/grocery-cart-screen';

// Ports AppRoutes.groceryCart ('/grocery/cart') from
// flutter_app/lib/services/grocery/presentation/grocery_cart_screen.dart
// (issue #392 / P7-04).
export default function GroceryCartRoute() {
  return <GroceryCartScreen storeType="grocery" />;
}
