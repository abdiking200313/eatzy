import { Text, View } from 'react-native';

// Ports AppRoutes.foodCategories ('/food/categories') from
// flutter_app/lib/app/app_routes.dart / app_router.dart (issue #358: route
// skeleton only -- real screen content lands in a later issue).
export default function FoodCategoriesScreen() {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <Text>/food/categories — not yet implemented</Text>
    </View>
  );
}
