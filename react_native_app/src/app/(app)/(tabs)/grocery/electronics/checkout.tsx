import { GroceryCheckoutScreen } from '@/features/grocery/grocery-checkout-screen';

// Ports AppRoutes.electronicsCheckout ('/grocery/electronics/checkout') from
// flutter_app/lib/services/grocery/presentation/grocery_checkout_screen.dart
// (issue #392 / P7-04).
export default function ElectronicsCheckoutRoute() {
  return <GroceryCheckoutScreen storeType="electronics" />;
}
