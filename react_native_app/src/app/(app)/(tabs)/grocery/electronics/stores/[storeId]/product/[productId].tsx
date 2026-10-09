import { useLocalSearchParams } from 'expo-router';
import { Text, View } from 'react-native';

// Ports AppRoutes.electronicsProduct ('/grocery/electronics/stores/:storeId/product/:productId') from
// flutter_app/lib/app/app_routes.dart / app_router.dart (issue #358: route
// skeleton only -- real screen content lands in a later issue).
export default function ElectronicsProductDetailsScreen() {
  const { storeId, productId } = useLocalSearchParams<{ storeId: string; productId: string }>();
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <Text>/grocery/electronics/stores/:storeId/product/:productId ({storeId} {productId}) — not yet implemented</Text>
    </View>
  );
}
