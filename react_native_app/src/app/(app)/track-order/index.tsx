import { Text, View } from 'react-native';

// Ports AppRoutes.trackOrder ('/track-order') from
// flutter_app/lib/app/app_routes.dart / app_router.dart (issue #358: route
// skeleton only -- real screen content lands in a later issue).
// Bare form kept only for old deep links with no order id -- the real reachable form is trackOrderDetails below (issue #43).
export default function TrackOrderScreen() {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <Text>/track-order — not yet implemented</Text>
    </View>
  );
}
