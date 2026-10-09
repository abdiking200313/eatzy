import { Link } from 'expo-router';
import { Text, View } from 'react-native';

// Ports NotFoundScreen (flutter_app/lib/app/not_found_screen.dart, issue
// #40): Expo Router's special `+not-found` file, rendered for any
// unmatched path in place of the framework's default error screen.
// Issue #358: route skeleton only -- styling/icon land in a later issue.
export default function NotFoundScreen() {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', gap: 12, padding: 24 }}>
      <Text>We couldn&apos;t find that page</Text>
      <Text>The link may be out of date, or the page may have moved.</Text>
      <Link href="/app">Go to home</Link>
    </View>
  );
}
