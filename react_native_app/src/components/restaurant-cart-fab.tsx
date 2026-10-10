import { MaterialIcons } from '@expo/vector-icons';
import { Pressable, Text, View } from 'react-native';

import { useServiceTheme } from '@/hooks/use-service-theme';
import { radius, shadows, spacing } from '@/theme/tokens';

export type RestaurantCartFabProps = {
  itemCount: number;
  onPress: () => void;
};

/**
 * Ports flutter_app/lib/services/food/presentation/widgets/
 * restaurant_cart_fab.dart's `RestaurantCartFab`: the "View cart" floating
 * action button. Hidden while the cart is empty; otherwise shows the
 * current item count and navigates to the cart on press.
 */
export function RestaurantCartFab({ itemCount, onPress }: RestaurantCartFabProps) {
  const palette = useServiceTheme('food');

  if (itemCount <= 0) {
    return null;
  }

  return (
    <Pressable
      testID="restaurant-cart-fab"
      accessibilityRole="button"
      accessibilityLabel={`View cart (${itemCount})`}
      onPress={onPress}
      style={[
        shadows.button,
        {
          backgroundColor: palette.accent,
          borderRadius: radius.full,
          paddingHorizontal: spacing.x5,
          paddingVertical: spacing.x3_5,
        },
      ]}
      className="flex-row items-center active:opacity-85">
      <View style={{ position: 'relative' }}>
        <MaterialIcons name="shopping-cart" size={20} color={palette.onAccent} />
        <View
          style={{ backgroundColor: palette.onAccent, top: -8, right: -10 }}
          className="absolute min-w-x4 items-center justify-center rounded-full px-x1">
          <Text style={{ color: palette.accent }} className="text-textXs font-outfitSemiBold" numberOfLines={1}>
            {itemCount}
          </Text>
        </View>
      </View>
      <View style={{ width: spacing.x2_5 }} />
      <Text style={{ color: palette.onAccent }} className="text-button font-outfitSemiBold">
        View cart
      </Text>
    </Pressable>
  );
}
