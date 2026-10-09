import { Text, View } from 'react-native';

// Ports AppRoutes.welcome ('/welcome') from
// flutter_app/lib/app/app_routes.dart / app_router.dart (issue #358: route
// skeleton only -- real screen content lands in a later issue).
// Also opened as '/welcome?revisit=true' (AppRoutes.welcomeRevisit) -- same screen, read later when the revisit-vs-redirect logic lands.
export default function WelcomeScreen() {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <Text>/welcome — not yet implemented</Text>
    </View>
  );
}
