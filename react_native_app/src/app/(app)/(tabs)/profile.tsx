import { Text, View } from 'react-native';

// Ports AppRoutes.profile ('/profile') from
// flutter_app/lib/app/app_routes.dart / app_router.dart (issue #358: route
// skeleton only -- real screen content lands in a later issue).
// Also the 'profile' AppRoutes.profile entry -- reachable only as this bottom-nav tab, not via a route push (see route_reachability_test.dart).
export default function ProfileScreen() {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <Text>/profile — not yet implemented</Text>
    </View>
  );
}
