import { PharmacyStoreListScreen } from '@/features/pharmacy/pharmacy-store-list-screen';

// Ports AppRoutes.pharmacy ('/pharmacy') from
// flutter_app/lib/services/pharmacy/presentation/pharmacy_store_list_screen.dart
// (issue #394 / P7-06).
// AppRoutes.pharmacyStores (the bare '/pharmacy/stores' prefix) intentionally has no matching route -- see app_routes.dart.
export default function PharmacyScreen() {
  return <PharmacyStoreListScreen />;
}
