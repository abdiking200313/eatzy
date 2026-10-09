import { Text, View } from 'react-native';

// Ports AppRoutes.pharmacy ('/pharmacy') from
// flutter_app/lib/app/app_routes.dart / app_router.dart (issue #358: route
// skeleton only -- real screen content lands in a later issue).
// AppRoutes.pharmacyStores (the bare '/pharmacy/stores' prefix) intentionally has no matching route -- see app_routes.dart.
export default function PharmacyStoreListScreen() {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <Text>/pharmacy — not yet implemented</Text>
    </View>
  );
}
