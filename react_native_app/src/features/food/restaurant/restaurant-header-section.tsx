/**
 * Ports `flutter_app/lib/services/food/presentation/widgets/restaurant_header_section.dart`'s
 * `RestaurantHeaderSection` (issue #383): the restaurant name/description/
 * item-count block above the category chip bar, plus a "store a • store b"
 * line once the restaurant's locations have loaded (hidden while loading
 * or when there are none -- mirrors the Dart `FutureBuilder`).
 */
import { MaterialIcons } from '@expo/vector-icons';
import { Text, View } from 'react-native';

import type { RestaurantLocation } from '@/features/food/api/restaurant-location';
import { restaurantMenuItemCount, type RestaurantMenu } from '@/features/food/api/restaurant-menu';
import { useServiceTheme } from '@/hooks/use-service-theme';
import { spacing } from '@/theme/tokens';

export const RESTAURANT_CONTENT_MAX_WIDTH = 760;

export type RestaurantHeaderSectionProps = {
  menu: RestaurantMenu;
  /** `undefined` while still loading. */
  locations: RestaurantLocation[] | undefined;
};

export function RestaurantHeaderSection({ menu, locations }: RestaurantHeaderSectionProps) {
  const palette = useServiceTheme('food');
  const description = menu.restaurant.description.trim();

  return (
    <View className="items-center">
      <View
        style={{
          width: '100%',
          maxWidth: RESTAURANT_CONTENT_MAX_WIDTH,
          paddingHorizontal: spacing.screenX,
          paddingTop: spacing.x6,
          paddingBottom: spacing.x5,
        }}>
        <Text className="text-text2xl font-outfitBold text-text">{menu.restaurant.name}</Text>
        {description.length > 0 && (
          <Text style={{ marginTop: spacing.x2 }} className="text-textSm font-outfitRegular text-textMuted">
            {menu.restaurant.description}
          </Text>
        )}
        <View style={{ marginTop: spacing.x3 }} className="flex-row items-center">
          <MaterialIcons name="restaurant-menu" size={18} color={palette.accent} />
          <Text style={{ marginLeft: spacing.x2 }} className="text-fontBoldSm font-outfitSemiBold text-text">
            {`${restaurantMenuItemCount(menu)} items`}
          </Text>
          <Text style={{ marginHorizontal: spacing.x2 }} className="text-textMuted">
            •
          </Text>
          <Text className="text-textSm font-outfitRegular text-textMuted">{`${menu.categories.length} categories`}</Text>
        </View>
        {locations && locations.length > 0 && (
          <View testID="restaurant-locations" style={{ marginTop: spacing.x3 }} className="flex-row items-start">
            <MaterialIcons name="storefront" size={18} color={palette.accent} />
            <Text style={{ marginLeft: spacing.x2 }} className="flex-1 text-textSm font-outfitRegular text-textMuted">
              {locations.map((location) => location.storeName).join(' • ')}
            </Text>
          </View>
        )}
      </View>
    </View>
  );
}
