import { Text, View } from 'react-native';

// Ports AppRoutes.privacyPolicy ('/settings/privacy-policy') from
// flutter_app/lib/app/app_routes.dart / app_router.dart (issue #358: route
// skeleton only -- real screen content lands in a later issue).
export default function PrivacyPolicyScreen() {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <Text>/settings/privacy-policy — not yet implemented</Text>
    </View>
  );
}
