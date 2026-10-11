import { MaterialIcons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { Text, View } from 'react-native';

import { AppScaffold } from '@/components/app-scaffold';
import { PrimaryButton } from '@/components/primary-button';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { AppRoutes } from '@/platform/navigation/app-routes';

/**
 * Ports NotFoundScreen (flutter_app/lib/app/not_found_screen.dart, issue
 * #40; styled in issue #543): Expo Router's special `+not-found` file,
 * rendered for any unmatched path in place of the framework's default error
 * screen. Gives the user a way back to a known-good route instead of a dead
 * end.
 */
export default function NotFoundScreen() {
  const colors = useSemanticColors();

  return (
    <AppScaffold title="Page not found">
      <View className="flex-1 items-center justify-center p-x8">
        <MaterialIcons name="search-off" size={48} color={colors.textMuted} />
        <Text className="mt-x3 text-center text-fontBoldBase font-outfitSemiBold text-text">
          We couldn&apos;t find that page
        </Text>
        <Text className="mt-x2 text-center text-textSm font-outfitRegular text-textMuted">
          The link may be out of date, or the page may have moved.
        </Text>
        <View className="mt-x5">
          {/* Flutter's `context.go(AppRoutes.mainApp)` replaces the
              location rather than stacking on top of the dead end. */}
          <PrimaryButton
            label="Go to home"
            fullWidth={false}
            onPress={() => router.replace(AppRoutes.mainApp)}
          />
        </View>
      </View>
    </AppScaffold>
  );
}
