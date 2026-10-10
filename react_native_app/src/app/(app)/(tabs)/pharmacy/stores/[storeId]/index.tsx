import { useLocalSearchParams } from 'expo-router';

import { PharmacyCatalogScreen } from '@/features/pharmacy/pharmacy-catalog-screen';

// Ports AppRoutes.pharmacyStore ('/pharmacy/stores/:storeId') from
// flutter_app/lib/app/app_router.dart, which reads the store's `name` and
// `photoUrl` query params into `PharmacyCatalogScreen` (issue #394 / P7-06).
export default function PharmacyStoreScreen() {
  const { storeId, name, photoUrl } = useLocalSearchParams<{ storeId: string; name?: string; photoUrl?: string }>();
  return <PharmacyCatalogScreen storeId={storeId} storeName={name} storeImageUrl={photoUrl} />;
}
