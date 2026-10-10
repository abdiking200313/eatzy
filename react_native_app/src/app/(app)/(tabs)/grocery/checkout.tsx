import { GroceryCheckoutScreen } from '@/features/grocery/grocery-checkout-screen';

// Ports AppRoutes.groceryCheckout ('/grocery/checkout') from
// flutter_app/lib/services/grocery/presentation/grocery_checkout_screen.dart
// (issue #392 / P7-04).
export default function GroceryCheckoutRoute() {
  return <GroceryCheckoutScreen storeType="grocery" />;
}
