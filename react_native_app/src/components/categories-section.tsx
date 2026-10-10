import { FlatList, Text, View } from 'react-native';

import { CategoryCard } from '@/components/category-card';
import type { Category } from '@/features/food/api/category';
import { spacing } from '@/theme/tokens';

export type CategoriesSectionProps = {
  categories: Category[];
  selectedCategoryId: string | null;
  onCategorySelected: (categoryId: string) => void;
};

// `CategoriesSection`'s fixed rail height in categories_section.dart.
const HEIGHT = 132;

/**
 * Ports `flutter_app/lib/services/food/presentation/widgets/categories_section.dart`'s
 * `CategoriesSection`: the food home screen's horizontal category-chip
 * rail. Edge-to-edge: no outer padding wraps this component -- the inset
 * comes from this list's own horizontal padding, same as the Dart source's
 * comment on its call site.
 */
export function CategoriesSection({ categories, selectedCategoryId, onCategorySelected }: CategoriesSectionProps) {
  if (categories.length === 0) {
    return (
      <View style={{ height: HEIGHT }} className="items-center justify-center">
        <Text className="text-textBase font-outfitRegular text-textMuted">No categories found</Text>
      </View>
    );
  }

  return (
    <View style={{ height: HEIGHT }}>
      <FlatList
        horizontal
        showsHorizontalScrollIndicator={false}
        data={categories}
        keyExtractor={(category) => category.id}
        contentContainerStyle={{ paddingHorizontal: spacing.screenX, gap: spacing.gridGap }}
        renderItem={({ item }) => (
          <CategoryCard category={item} isSelected={item.id === selectedCategoryId} onPress={() => onCategorySelected(item.id)} />
        )}
      />
    </View>
  );
}
