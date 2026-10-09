import { Text, View } from 'react-native';

// Ports AppRoutes.mainApp ('/app') from
// flutter_app/lib/app/app_routes.dart / app_router.dart (issue #358: route
// skeleton only -- real screen content lands in a later issue).
// The Home bottom-nav tab.
export default function SuperAppHomeScreen() {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <Text>/app — not yet implemented</Text>
    </View>
  );
}
