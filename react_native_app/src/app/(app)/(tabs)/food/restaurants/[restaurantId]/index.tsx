import { useLocalSearchParams } from 'expo-router';

import { RestaurantScreen } from '@/features/food/restaurant/restaurant-screen';

// Ports AppRoutes.foodRestaurant ('/food/restaurants/:restaurantId') from
// flutter_app/lib/app/app_routes.dart / app_router.dart. The screen itself
// (issue #383) lives in src/features/food/restaurant/restaurant-screen.tsx;
// it is keyed on the id so switching restaurants resets its selected
// category, mirroring the Dart `didUpdateWidget` reset.
// AppRoutes.foodRestaurants (the bare '/food/restaurants' prefix) intentionally has no matching route -- see app_routes.dart.
export default function RestaurantRoute() {
  const { restaurantId } = useLocalSearchParams<{ restaurantId: string }>();
  const id = restaurantId ?? '';
  return <RestaurantScreen key={id} restaurantId={id} />;
}
