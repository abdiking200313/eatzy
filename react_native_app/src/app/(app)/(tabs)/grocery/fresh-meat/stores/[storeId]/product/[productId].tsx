import { useLocalSearchParams } from 'expo-router';

import { GroceryProductDetailsScreen } from '@/features/grocery/grocery-product-details-screen';

// Ports AppRoutes.freshMeatProduct ('/grocery/fresh-meat/stores/:storeId/product/:productId') from
// flutter_app/lib/services/grocery/presentation/grocery_product_details_screen.dart
// (issue #391 / P7-03).
export default function FreshMeatProductDetailsRoute() {
  const { storeId, productId } = useLocalSearchParams<{ storeId: string; productId: string }>();
  return <GroceryProductDetailsScreen storeId={storeId} productId={productId} storeType="fresh_meat" />;
}
