import { GroceryCartScreen } from '@/features/grocery/grocery-cart-screen';

// Ports AppRoutes.freshMeatCart ('/grocery/fresh-meat/cart') from
// flutter_app/lib/services/grocery/presentation/grocery_cart_screen.dart
// (issue #392 / P7-04).
export default function FreshMeatCartRoute() {
  return <GroceryCartScreen storeType="fresh_meat" />;
}
