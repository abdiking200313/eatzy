import { Text, View } from 'react-native';

// Ports AppRoutes.merchantCatalog ('/merchant/catalog') from
// flutter_app/lib/app/app_routes.dart / app_router.dart (issue #358: route
// skeleton only -- real screen content lands in a later issue).
export default function CatalogScreen() {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <Text>/merchant/catalog — not yet implemented</Text>
    </View>
  );
}
