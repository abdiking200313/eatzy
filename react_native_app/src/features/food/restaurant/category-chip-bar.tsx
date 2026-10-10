/**
 * Ports `flutter_app/lib/services/food/presentation/widgets/category_header_delegate.dart`'s
 * `CategoryHeaderDelegate` (issue #383): the horizontally scrolling
 * category chip bar that sticks to the top of the restaurant menu once the
 * hero scrolls away. Flutter needs a `SliverPersistentHeaderDelegate` for
 * the "pinned" part; here the bar is a plain component and the menu list
 * pins it via FlashList's `stickyHeaderIndices` (see
 * `restaurant-menu-view.tsx`).
 */
import { Pressable, ScrollView, Text, View } from 'react-native';

import type { MenuCategory } from '@/features/food/api/restaurant-menu';
import { useServiceTheme } from '@/hooks/use-service-theme';
import { spacing } from '@/theme/tokens';

import { RESTAURANT_CONTENT_MAX_WIDTH } from './restaurant-header-section';

/** Mirrors `kCategoryHeaderExtent`: the bar's fixed height (18 top / 12 bottom padding around a 36px chip). */
export const CATEGORY_CHIP_BAR_HEIGHT = 72;

export type CategoryChipBarProps = {
  categories: MenuCategory[];
  selectedCategoryId: string;
  onSelected: (category: MenuCategory) => void;
  /** Extra top padding when pinned below a status bar/notch (the stuck copy only). */
  topInset?: number;
  /** Mirrors the Dart delegate's `overlapsContent` shadow: shown only while stuck over the menu. */
  elevated?: boolean;
};

export function CategoryChipBar({ categories, selectedCategoryId, onSelected, topInset = 0, elevated = false }: CategoryChipBarProps) {
  const palette = useServiceTheme('food');

  return (
    <View
      testID="category-chip-bar"
      style={[
        { backgroundColor: palette.background, height: CATEGORY_CHIP_BAR_HEIGHT + topInset, paddingTop: topInset },
        elevated && {
          shadowColor: '#0F172A',
          shadowOpacity: 20 / 255,
          shadowRadius: 12,
          shadowOffset: { width: 0, height: 4 },
          elevation: 4,
        },
      ]}
      className="items-center">
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        style={{ width: '100%', maxWidth: RESTAURANT_CONTENT_MAX_WIDTH }}
        contentContainerStyle={{
          paddingHorizontal: spacing.screenX,
          paddingTop: 18,
          paddingBottom: spacing.x3,
          gap: spacing.x2,
          alignItems: 'center',
        }}>
        {categories.map((category) => {
          const isSelected = category.id === selectedCategoryId;
          return (
            <Pressable
              key={category.id}
              accessibilityRole="button"
              accessibilityLabel={category.name}
              accessibilityState={{ selected: isSelected }}
              onPress={() => onSelected(category)}
              style={{
                height: 36,
                paddingHorizontal: spacing.x3,
                borderRadius: 8,
                borderWidth: 1,
                borderColor: isSelected ? palette.accent : palette.border,
                backgroundColor: isSelected ? palette.accent : palette.soft,
              }}
              className="items-center justify-center active:opacity-80">
              <Text style={{ color: isSelected ? palette.onAccent : palette.accent }} className="text-textXs font-outfitMedium">
                {category.name}
              </Text>
            </Pressable>
          );
        })}
      </ScrollView>
    </View>
  );
}
