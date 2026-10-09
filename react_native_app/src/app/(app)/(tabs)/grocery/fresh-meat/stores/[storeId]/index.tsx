import { useLocalSearchParams } from 'expo-router';
import { Text, View } from 'react-native';

// Ports AppRoutes.freshMeatStore ('/grocery/fresh-meat/stores/:storeId') from
// flutter_app/lib/app/app_routes.dart / app_router.dart (issue #358: route
// skeleton only -- real screen content lands in a later issue).
export default function FreshMeatStoreScreen() {
  const { storeId } = useLocalSearchParams<{ storeId: string }>();
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <Text>/grocery/fresh-meat/stores/:storeId ({storeId}) — not yet implemented</Text>
    </View>
  );
}
