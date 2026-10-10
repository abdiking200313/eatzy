import { MaterialIcons } from '@expo/vector-icons';
import { Pressable, Text, View } from 'react-native';
import Svg, { Defs, LinearGradient, Rect, Stop } from 'react-native-svg';

import { rawColors, radius, spacing } from '@/theme/tokens';

export type PromoBannerProps = {
  onExplore: () => void;
};

/**
 * Ports `flutter_app/lib/features/super_app/presentation/widgets/promo_banner.dart`'s
 * `PromoBanner`: a wide gradient hero card with a title, an "Explore" CTA,
 * and a storefront icon badge.
 */
export function PromoBanner({ onExplore }: PromoBannerProps) {
  return (
    <View
      style={{ minHeight: 176, borderRadius: radius.hero, padding: 22, overflow: 'hidden' }}
      className="w-full flex-row items-center">
      <Svg style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 }} width="100%" height="100%">
        <Defs>
          <LinearGradient id="promoBannerGradient" x1="0%" y1="0%" x2="100%" y2="100%">
            <Stop offset="0" stopColor={rawColors.blue500} />
            <Stop offset="1" stopColor={rawColors.blue600} />
          </LinearGradient>
        </Defs>
        <Rect width="100%" height="100%" fill="url(#promoBannerGradient)" />
      </Svg>

      <View className="flex-1 justify-between">
        <Text style={{ lineHeight: 24 * 1.2 }} className="text-textLg font-outfitBold text-white">
          {'Everything nearby,\none tap away'}
        </Text>
        <Pressable
          accessibilityRole="button"
          onPress={onExplore}
          style={{ minHeight: 32, paddingHorizontal: spacing.x4, borderColor: rawColors.white, borderWidth: 1, borderRadius: radius.control }}
          className="mt-x3 items-center justify-center self-start active:opacity-80">
          <Text className="text-button text-white">Explore</Text>
        </Pressable>
      </View>

      <View style={{ width: spacing.x3 }} />
      <View
        style={{ width: 64, height: 64, backgroundColor: 'rgba(255, 255, 255, 0.16)', borderRadius: radius.full }}
        className="items-center justify-center">
        <MaterialIcons name="storefront" size={34} color={rawColors.white} />
      </View>
    </View>
  );
}
