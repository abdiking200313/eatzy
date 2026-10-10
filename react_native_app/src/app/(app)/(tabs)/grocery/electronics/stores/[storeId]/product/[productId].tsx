import { useLocalSearchParams } from 'expo-router';

import { GroceryProductDetailsScreen } from '@/features/grocery/grocery-product-details-screen';

// Ports AppRoutes.electronicsProduct ('/grocery/electronics/stores/:storeId/product/:productId') from
// flutter_app/lib/services/grocery/presentation/grocery_product_details_screen.dart
// (issue #391 / P7-03).
export default function ElectronicsProductDetailsRoute() {
  const { storeId, productId } = useLocalSearchParams<{ storeId: string; productId: string }>();
  return <GroceryProductDetailsScreen storeId={storeId} productId={productId} storeType="electronics" />;
}
