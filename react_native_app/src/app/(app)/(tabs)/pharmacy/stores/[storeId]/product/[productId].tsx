import { useLocalSearchParams } from 'expo-router';

import { PharmacyProductDetailsScreen } from '@/features/pharmacy/pharmacy-product-details-screen';

// Ports AppRoutes.pharmacyProduct ('/pharmacy/stores/:storeId/product/:productId') from
// flutter_app/lib/services/pharmacy/presentation/pharmacy_product_details_screen.dart
// (issue #395 / P7-07).
export default function PharmacyProductDetailsRoute() {
  const { storeId, productId } = useLocalSearchParams<{ storeId: string; productId: string }>();
  return <PharmacyProductDetailsScreen storeId={storeId} productId={productId} />;
}
