import { useLocalSearchParams } from 'expo-router';
import { Text, View } from 'react-native';

// Ports AppRoutes.trackOrderDetails ('/track-order/:serviceId/:orderId') from
// flutter_app/lib/app/app_routes.dart / app_router.dart (issue #358: route
// skeleton only -- real screen content lands in a later issue).
export default function TrackOrderDetailsScreen() {
  const { serviceId, orderId } = useLocalSearchParams<{ serviceId: string; orderId: string }>();
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <Text>/track-order/:serviceId/:orderId ({serviceId} {orderId}) — not yet implemented</Text>
    </View>
  );
}
