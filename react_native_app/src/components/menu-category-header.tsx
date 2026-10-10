import { Text, View } from 'react-native';

import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { spacing } from '@/theme/tokens';

export type MenuCategoryHeaderProps = {
  name: string;
  itemCount: number;
};

/**
 * Ports flutter_app/lib/services/food/presentation/widgets/
 * restaurant_menu_view.dart's `MenuCategorySectionHeader`: a category's
 * name/item-count heading within the menu list.
 *
 * Unlike the Dart source (a plain, non-pinned `SliverToBoxAdapter` -- only
 * the `CategoryHeaderDelegate` chip bar pins there), this is rendered as one
 * of `RestaurantMenuScreen`'s FlashList rows with its index listed in
 * `stickyHeaderIndices`, so it sticks to the top of the menu while its own
 * category's items scroll past -- the RN substitute for "always know which
 * category you're looking at" that this issue's `stickyHeaderIndices`
 * guidance calls for. Needs an opaque background (unlike the Dart
 * transparent row) so item rows don't show through while it's pinned.
 */
export function MenuCategoryHeader({ name, itemCount }: MenuCategoryHeaderProps) {
  const colors = useSemanticColors();

  return (
    <View
      style={{ backgroundColor: colors.bg, paddingHorizontal: spacing.screenX, paddingTop: spacing.x4, paddingBottom: spacing.x2 }}
      className="flex-row items-baseline border-b border-border">
      <Text style={{ flex: 1 }} className="text-sectionTitle font-outfitSemiBold text-text">
        {name}
      </Text>
      <Text style={{ color: colors.textMuted }} className="text-textXs font-outfitMedium">
        {`${itemCount} ${itemCount === 1 ? 'item' : 'items'}`}
      </Text>
    </View>
  );
}
