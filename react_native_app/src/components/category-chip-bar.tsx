import { Pressable, ScrollView, Text, View } from 'react-native';

import { useServiceTheme } from '@/hooks/use-service-theme';
import type { ServiceId } from '@/theme/service-theme';
import { radius, spacing } from '@/theme/tokens';

export type CategoryChip = {
  id: string;
  name: string;
};

export type CategoryChipBarProps = {
  categories: CategoryChip[];
  selectedCategoryId: string | null;
  onSelected: (categoryId: string) => void;
  service?: ServiceId;
};

/**
 * Ports flutter_app/lib/services/food/presentation/widgets/
 * category_header_delegate.dart's `CategoryHeaderDelegate`: the
 * horizontally-scrolling row of category `ChoiceChip`s that lets a shopper
 * jump straight to a category.
 *
 * The Dart widget is a `SliverPersistentHeader` that pins below the
 * collapsing hero once scrolled past, with its selected chip kept in sync
 * from scroll position via a `ScrollController` listener computing each
 * section's on-screen offset. There is no sliver-equivalent pinning
 * mechanism at this presentational level in RN, and FlashList's own
 * `stickyHeaderIndices` (used by `MenuCategoryHeader` instead, inside the
 * scrolling menu) covers the "always know which category you're in"
 * purpose structurally. So this bar is rendered as a fixed, always-visible
 * strip directly under the restaurant hero -- simpler than reproducing the
 * Dart scroll-position math, at the cost of always being visible (rather
 * than appearing only once scrolled past the header text). The screen
 * hosting this is responsible for keeping `selectedCategoryId` in sync with
 * which category is actually on screen (e.g. from the menu list's own
 * viewability callback) and for scrolling the menu to a tapped category.
 */
export function CategoryChipBar({ categories, selectedCategoryId, onSelected, service = 'food' }: CategoryChipBarProps) {
  const palette = useServiceTheme(service);

  if (categories.length === 0) {
    return null;
  }

  return (
    <View style={{ backgroundColor: palette.background, paddingVertical: spacing.x3 }} className="border-b border-border">
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={{ paddingHorizontal: spacing.screenX, gap: spacing.x2 }}>
        {categories.map((category) => {
          const isSelected = category.id === selectedCategoryId;
          return (
            <Pressable
              key={category.id}
              testID={`category-chip-${category.id}`}
              accessibilityRole="button"
              accessibilityState={{ selected: isSelected }}
              onPress={() => onSelected(category.id)}
              style={{
                borderRadius: radius.chip,
                borderWidth: 1,
                borderColor: isSelected ? palette.accent : palette.border,
                backgroundColor: isSelected ? palette.accent : palette.soft,
                paddingHorizontal: spacing.x3_5,
                paddingVertical: spacing.x2,
              }}
              className="active:opacity-80">
              <Text
                style={{ color: isSelected ? palette.onAccent : palette.accent }}
                className="text-textXs font-outfitMedium">
                {category.name}
              </Text>
            </Pressable>
          );
        })}
      </ScrollView>
    </View>
  );
}
