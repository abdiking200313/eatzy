import { Text, View } from 'react-native';

// Ports AppRoutes.resetPassword ('/reset-password') from
// flutter_app/lib/app/app_routes.dart / app_router.dart (issue #358: route
// skeleton only -- real screen content lands in a later issue).
// Reachable both from Settings (normal session) and a password-recovery email deep link (temporary recovery session).
export default function ResetPasswordScreen() {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <Text>/reset-password — not yet implemented</Text>
    </View>
  );
}
