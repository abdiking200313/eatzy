import { Text, View } from 'react-native';

// Ports AppRoutes.foodExplore ('/food/explore') from
// flutter_app/lib/app/app_routes.dart / app_router.dart (issue #358: route
// skeleton only -- real screen content lands in a later issue).
// Reads optional ?categoryId=&categoryName= query params in app_router.dart to pre-filter the list; not wired up yet.
export default function FoodExploreScreen() {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <Text>/food/explore — not yet implemented</Text>
    </View>
  );
}
