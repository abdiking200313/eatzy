import { MaterialIcons } from '@expo/vector-icons';
import { Pressable, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Svg, { Defs, LinearGradient, Rect, Stop } from 'react-native-svg';

import { AppSearchBar } from '@/components/app-search-bar';
import { rawColors, radius, spacing } from '@/theme/tokens';

export type HomeHeaderProps = {
  onSearch: () => void;
  onNotifications: () => void;
  onSettings: () => void;
};

/**
 * Ports `flutter_app/lib/features/super_app/presentation/widgets/home_header.dart`'s
 * `HomeHeader`: the gradient top bar (wordmark + notifications/settings
 * icons) with the search bar below it, bottom corners rounded.
 */
export function HomeHeader({ onSearch, onNotifications, onSettings }: HomeHeaderProps) {
  return (
    <View style={{ borderBottomLeftRadius: radius.hero, borderBottomRightRadius: radius.hero, overflow: 'hidden' }}>
      <Svg style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 }} width="100%" height="100%">
        <Defs>
          <LinearGradient id="homeHeaderGradient" x1="0%" y1="0%" x2="100%" y2="100%">
            <Stop offset="0" stopColor={rawColors.blue500} />
            <Stop offset="1" stopColor={rawColors.blue600} />
          </LinearGradient>
        </Defs>
        <Rect width="100%" height="100%" fill="url(#homeHeaderGradient)" />
      </Svg>
      <SafeAreaView edges={['top']}>
        <View style={{ paddingLeft: spacing.x5, paddingRight: spacing.x3, paddingTop: spacing.x2_5, paddingBottom: spacing.x6 }}>
          <View className="flex-row items-center">
            <Text style={{ letterSpacing: -0.4 }} className="text-textXl font-outfitBold text-white">
              zivo
            </Text>
            <View className="flex-1" />
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Notifications"
              onPress={onNotifications}
              className="h-x10 w-x10 items-center justify-center active:opacity-70">
              <MaterialIcons name="notifications-none" size={24} color={rawColors.white} />
            </Pressable>
            <View style={{ width: spacing.iconButtonGap }} />
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Settings"
              onPress={onSettings}
              className="h-x10 w-x10 items-center justify-center active:opacity-70">
              <MaterialIcons name="settings" size={24} color={rawColors.white} />
            </Pressable>
          </View>
          <View style={{ height: 18 }} />
          <AppSearchBar hintText="Search restaurants, stores..." onPress={onSearch} />
        </View>
      </SafeAreaView>
    </View>
  );
}
