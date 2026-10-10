/**
 * Ports `flutter_app/lib/services/food/presentation/widgets/restaurant_cart_fab.dart`'s
 * `RestaurantCartFab` (issue #383): the "View cart" extended floating
 * action button. Hidden while the food cart is empty; otherwise shows the
 * current item count as a badge.
 */
import { MaterialIcons } from '@expo/vector-icons';
import { Pressable, Text, View } from 'react-native';

import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { rawColors, spacing } from '@/theme/tokens';

export type RestaurantCartFabProps = {
  itemCount: number;
  onViewCart: () => void;
};

export function RestaurantCartFab({ itemCount, onViewCart }: RestaurantCartFabProps) {
  const colors = useSemanticColors();
  if (itemCount === 0) {
    return null;
  }

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={`View cart (${itemCount})`}
      onPress={onViewCart}
      style={{ height: 56, paddingHorizontal: spacing.x5, borderRadius: 16, backgroundColor: colors.primary }}
      className="flex-row items-center shadow-card active:opacity-90">
      <View>
        <MaterialIcons name="shopping-cart" size={24} color={colors.onPrimary} />
        <View
          style={{ position: 'absolute', top: -6, right: -10, minWidth: 18, height: 18, borderRadius: 9, backgroundColor: rawColors.red600 }}
          className="items-center justify-center px-x1">
          <Text style={{ color: rawColors.white, fontSize: 11 }} className="font-outfitSemiBold">
            {itemCount}
          </Text>
        </View>
      </View>
      <Text style={{ marginLeft: spacing.x4, color: colors.onPrimary }} className="text-button font-outfitSemiBold">
        View cart
      </Text>
    </Pressable>
  );
}
