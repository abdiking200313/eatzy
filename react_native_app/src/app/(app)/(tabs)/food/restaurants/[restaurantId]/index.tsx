import { useLocalSearchParams } from 'expo-router';
import { Text, View } from 'react-native';

// Ports AppRoutes.foodRestaurant ('/food/restaurants/:restaurantId') from
// flutter_app/lib/app/app_routes.dart / app_router.dart (issue #358: route
// skeleton only -- real screen content lands in a later issue).
// AppRoutes.foodRestaurants (the bare '/food/restaurants' prefix) intentionally has no matching route -- see app_routes.dart.
export default function RestaurantScreen() {
  const { restaurantId } = useLocalSearchParams<{ restaurantId: string }>();
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <Text>/food/restaurants/:restaurantId ({restaurantId}) — not yet implemented</Text>
    </View>
  );
}
