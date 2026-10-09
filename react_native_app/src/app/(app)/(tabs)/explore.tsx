import { Text, View } from 'react-native';

// Ports AppRoutes.explore ('/explore') from
// flutter_app/lib/app/app_routes.dart / app_router.dart (issue #358: route
// skeleton only -- real screen content lands in a later issue).
// Platform-wide discovery/search tab (lib/platform/discovery/) -- distinct from the Expo template's old demo 'Explore' tab, which this file replaces.
export default function ExploreScreen() {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <Text>/explore — not yet implemented</Text>
    </View>
  );
}
