import { Text, View } from 'react-native';

// Ports AppRoutes.food ('/food') from
// flutter_app/lib/app/app_routes.dart / app_router.dart (issue #358: route
// skeleton only -- real screen content lands in a later issue).
export default function FoodHomeScreen() {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <Text>/food — not yet implemented</Text>
    </View>
  );
}
