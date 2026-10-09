import { useLocalSearchParams } from 'expo-router';
import { Text, View } from 'react-native';

// Ports AppRoutes.foodMenuItem ('/food/restaurants/:restaurantId/item/:itemId') from
// flutter_app/lib/app/app_routes.dart / app_router.dart (issue #358: route
// skeleton only -- real screen content lands in a later issue).
export default function MenuItemDetailsScreen() {
  const { restaurantId, itemId } = useLocalSearchParams<{ restaurantId: string; itemId: string }>();
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <Text>/food/restaurants/:restaurantId/item/:itemId ({restaurantId} {itemId}) — not yet implemented</Text>
    </View>
  );
}
