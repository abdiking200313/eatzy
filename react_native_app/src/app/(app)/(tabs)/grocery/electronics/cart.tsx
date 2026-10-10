import { GroceryCartScreen } from '@/features/grocery/grocery-cart-screen';

// Ports AppRoutes.electronicsCart ('/grocery/electronics/cart') from
// flutter_app/lib/services/grocery/presentation/grocery_cart_screen.dart
// (issue #392 / P7-04).
export default function ElectronicsCartRoute() {
  return <GroceryCartScreen storeType="electronics" />;
}
