import { Redirect, useLocalSearchParams } from 'expo-router';

// Legacy redirect, ported from app_router.dart's `_standaloneProtectedRoutes`
// (or the root GoRoute): AppRoutes.restaurant ('/restaurants/:restaurantId') -> '/food/restaurants/[restaurantId]'.
// Issue #358: route skeleton only.
export default function RestaurantLegacyRedirect() {
  const { restaurantId } = useLocalSearchParams<{ restaurantId: string }>();
  return <Redirect href={{ pathname: '/food/restaurants/[restaurantId]', params: { restaurantId } }} />;
}
