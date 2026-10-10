/**
 * Ports `flutter_app/lib/services/food/presentation/widgets/menu_item_card.dart`'s
 * `MenuItemCard` (issue #383): one menu item row -- a 100x100 photo (or a
 * food-accent fallback tile), name, optional description, price, and an
 * inline add-to-cart button. Tapping the card opens the item's details
 * route; the add button adds one unit.
 */
import { MaterialIcons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { useState } from 'react';
import { ActivityIndicator, Text, View } from 'react-native';

import { AddToCartButton } from '@/components/add-to-cart-button';
import { OutlinedCard } from '@/components/outlined-card';
import type { MenuItem } from '@/features/food/api/restaurant-menu';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { useServiceTheme } from '@/hooks/use-service-theme';
import { formatCents } from '@/platform/money/format';
import { radius, spacing } from '@/theme/tokens';

const IMAGE_SIZE = 100;

export type MenuItemCardProps = {
  item: MenuItem;
  /** Opens this item's details route -- the Dart widget pushes `AppRoutes.foodMenuItemDetails(restaurantId, item.id)` itself; here the caller wires navigation so this stays presentational. */
  onPress: () => void;
  /** Called with the quantity to add: `1` from the inline add button. */
  onAddToCart: (quantity: number) => void;
};

export function MenuItemCard({ item, onPress, onAddToCart }: MenuItemCardProps) {
  const colors = useSemanticColors();

  // White card only -- the per-service accent stays confined to the
  // fallback imagery, never the card fill or border.
  return (
    <OutlinedCard
      testID={`menu-item-${item.id}`}
      backgroundColor={colors.card}
      borderColor={colors.border}
      borderRadius={radius.card}
      padding={spacing.x3}
      onPress={onPress}>
      <View className="flex-row items-center">
        <View style={{ width: IMAGE_SIZE, height: IMAGE_SIZE, borderRadius: radius.tile }} className="overflow-hidden">
          <MenuItemImage imageUrl={item.imageUrl} />
        </View>
        <View style={{ marginLeft: spacing.x3_5 }} className="flex-1">
          <Text className="text-fontBoldBase font-outfitSemiBold text-text">{item.name}</Text>
          {item.description.trim().length > 0 && (
            <Text style={{ marginTop: spacing.x1 }} className="text-textSm font-outfitRegular text-textMuted">
              {item.description}
            </Text>
          )}
          <View style={{ marginTop: spacing.x3_5 }} className="flex-row items-center">
            <Text className="flex-1 text-fontBoldBase font-outfitSemiBold text-primary">{formatCents(item.price)}</Text>
            <AddToCartButton tooltip={`Add ${item.name} to cart`} onPress={() => onAddToCart(1)} />
          </View>
        </View>
      </View>
    </OutlinedCard>
  );
}

function MenuItemImage({ imageUrl }: { imageUrl: string }) {
  const url = imageUrl.trim();
  const [status, setStatus] = useState<'loading' | 'loaded' | 'error'>(url ? 'loading' : 'error');

  return (
    <View className="flex-1">
      {status !== 'loaded' && <MenuImageFallback showLoader={status === 'loading'} />}
      {url.length > 0 && status !== 'error' && (
        <Image
          source={{ uri: url }}
          style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 }}
          contentFit="cover"
          cachePolicy="memory-disk"
          onLoad={() => setStatus('loaded')}
          onError={() => setStatus('error')}
        />
      )}
    </View>
  );
}

function MenuImageFallback({ showLoader }: { showLoader: boolean }) {
  const palette = useServiceTheme('food');
  return (
    <View style={{ backgroundColor: palette.soft }} className="flex-1 items-center justify-center">
      {showLoader ? (
        <ActivityIndicator color={palette.accent} />
      ) : (
        <MaterialIcons name="lunch-dining" size={34} color={palette.accent} />
      )}
    </View>
  );
}
