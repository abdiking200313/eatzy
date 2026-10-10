import { Text, View } from 'react-native';

import { AddToCartButton } from '@/components/add-to-cart-button';
import { OutlinedCard } from '@/components/outlined-card';
import { PhotoThumbnail } from '@/components/photo-thumbnail';
import { ServiceIconChip } from '@/components/service-icon-chip';
import { formatCents } from '@/platform/money/format';
import { radius, spacing } from '@/theme/tokens';

export type MenuItemCardItem = {
  id: string;
  name: string;
  description: string;
  /** Integer cents. */
  price: number;
  imageUrl: string;
};

export type MenuItemCardProps = {
  item: MenuItemCardItem;
  onPress: () => void;
  onAddToCart: () => void;
};

const THUMBNAIL_SIZE = 100;

/**
 * Ports flutter_app/lib/services/food/presentation/widgets/
 * menu_item_card.dart's `MenuItemCard`: one menu item row -- photo, name,
 * description, price, and an inline add-to-cart button. Tapping the card
 * (outside the button) opens the item's details screen; tapping the button
 * adds one unit directly, mirroring the Dart `onAddToCart(1)` call.
 *
 * Unlike the Dart `_MenuItemImage` (a bespoke `CachedNetworkImage` with its
 * own loading spinner/error fallback), this reuses this app's existing
 * `PhotoThumbnail` (as `StoreRowCard` and `CartThumbnail` already do) rather
 * than a one-off reimplementation -- it shows the same fallback tile for
 * "no photo" and "failed to load", just without a distinct loading-spinner
 * state, matching every other photo thumbnail already in this app.
 */
export function MenuItemCard({ item, onPress, onAddToCart }: MenuItemCardProps) {
  const trimmedDescription = item.description.trim();

  return (
    <OutlinedCard borderRadius={radius.card} padding={spacing.x3} onPress={onPress} testID={`menu-item-card-${item.id}`}>
      <View className="flex-row items-center">
        <PhotoThumbnail
          imageUrl={item.imageUrl}
          size={THUMBNAIL_SIZE}
          fallback={<ServiceIconChip icon="lunch-dining" iconSize={34} size={THUMBNAIL_SIZE} service="food" />}
        />
        <View style={{ width: spacing.x3_5 }} />
        <View style={{ flex: 1 }}>
          <Text className="text-fontBoldBase font-outfitSemiBold text-text">{item.name}</Text>
          {trimmedDescription.length > 0 && (
            <>
              <View style={{ height: spacing.x1 }} />
              <Text className="text-textSm font-outfitRegular text-text" numberOfLines={2}>
                {trimmedDescription}
              </Text>
            </>
          )}
          <View style={{ height: spacing.x3_5 }} />
          <View className="flex-row items-center">
            <Text style={{ flex: 1 }} className="text-fontBoldBase font-outfitSemiBold text-primary">
              {formatCents(item.price)}
            </Text>
            <AddToCartButton tooltip={`Add ${item.name} to cart`} onPress={onAddToCart} />
          </View>
        </View>
      </View>
    </OutlinedCard>
  );
}
