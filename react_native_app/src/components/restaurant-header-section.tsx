import { MaterialIcons } from '@expo/vector-icons';
import { Text, View } from 'react-native';

import { useServiceTheme } from '@/hooks/use-service-theme';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { spacing } from '@/theme/tokens';

export type RestaurantHeaderSectionProps = {
  name: string;
  description: string;
  itemCount: number;
  categoryCount: number;
};

/**
 * Ports flutter_app/lib/services/food/presentation/widgets/
 * restaurant_header_section.dart's `RestaurantHeaderSection`: the
 * name/description/item-count block sitting above the menu on
 * `RestaurantScreen`.
 *
 * The Dart widget also resolves and shows a "store a • store b" line from
 * `RestaurantLocationRepository.fetchLocations` once it loads. There is no
 * RN port of that repository yet (issue #383's sibling data pass only
 * ported `RestaurantMenu`/`useRestaurantMenu`) -- the locations line is
 * dropped here rather than guessed at; a future issue can add a
 * `locations` prop once that repository exists.
 */
export function RestaurantHeaderSection({ name, description, itemCount, categoryCount }: RestaurantHeaderSectionProps) {
  const colors = useSemanticColors();
  const palette = useServiceTheme('food');
  const trimmedDescription = description.trim();

  return (
    <View style={{ paddingHorizontal: spacing.screenX, paddingTop: spacing.x6, paddingBottom: spacing.x5 }}>
      <Text className="text-text2xl font-outfitBold text-text">{name}</Text>
      {trimmedDescription.length > 0 && (
        <>
          <View style={{ height: spacing.x2 }} />
          <Text className="text-textSm font-outfitRegular text-text">{trimmedDescription}</Text>
        </>
      )}
      <View style={{ height: spacing.x3 }} />
      <View className="flex-row items-center">
        <MaterialIcons name="restaurant-menu" size={18} color={palette.accent} />
        <View style={{ width: spacing.x2 }} />
        <Text className="text-fontBoldSm font-outfitSemiBold text-text">{`${itemCount} items`}</Text>
        <Text style={{ paddingHorizontal: spacing.x2, color: colors.textMuted }} className="text-textSm font-outfitRegular">
          {'•'}
        </Text>
        <Text className="text-textSm font-outfitRegular text-text">{`${categoryCount} categories`}</Text>
      </View>
    </View>
  );
}
