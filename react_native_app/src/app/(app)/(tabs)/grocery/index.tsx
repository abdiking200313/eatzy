import { Text, View } from 'react-native';

// Ports AppRoutes.grocery ('/grocery') from
// flutter_app/lib/app/app_routes.dart / app_router.dart (issue #358: route
// skeleton only -- real screen content lands in a later issue).
// AppRoutes.groceryStores/freshMeatStore-prefix equivalents intentionally have no matching bare route -- see app_routes.dart.
export default function GroceryScreen() {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <Text>/grocery — not yet implemented</Text>
    </View>
  );
}
