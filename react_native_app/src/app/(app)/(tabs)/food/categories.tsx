/**
 * Ports `flutter_app/lib/services/food/presentation/food_categories_screen.dart`'s
 * `FoodCategoriesScreen` (issue #385): the food "See All" categories page --
 * a two-column grid of white category cards, each opening the food explore
 * list pre-filtered to that category (`/food/explore?categoryId=&categoryName=`,
 * see `foodExplorePath`).
 *
 * Data comes from `useFoodCategories()` (`use-food-browse.ts`), a
 * `useQuery` over the existing `fetchCategories` repository function --
 * standing in for the Dart screen's one-shot `late final Future`.
 *
 * Deviation from the Dart source: loading/error/empty chrome reuses this
 * app's generic `LoadingState`/`ErrorState`/`EmptyState` components (same
 * convention as `food/index.tsx`) instead of the bespoke `_Message` widget.
 * The copy is preserved verbatim; the error view gains a "Try again" retry
 * button (Dart has none) and uses `ErrorState`'s fixed icon rather than
 * `cloud_off_outlined`.
 */
import { router } from 'expo-router';
import { FlatList, Text, View } from 'react-native';

import { AppScaffold } from '@/components/app-scaffold';
import { EmptyState } from '@/components/empty-state';
import { ErrorState } from '@/components/error-state';
import { LoadingState } from '@/components/loading-state';
import { OutlinedCard } from '@/components/outlined-card';
import { ServiceIconChip } from '@/components/service-icon-chip';
import type { Category } from '@/features/food/api/category';
import { useFoodCategories } from '@/features/food/api/use-food-browse';
import { foodExplorePath } from '@/platform/navigation/app-routes';
import { radius, spacing } from '@/theme/tokens';

const TITLE = 'Food categories';

export default function FoodCategoriesScreen() {
  const categoriesQuery = useFoodCategories();

  if (categoriesQuery.isPending) {
    return (
      <AppScaffold title={TITLE} showBackButton>
        <LoadingState />
      </AppScaffold>
    );
  }

  if (categoriesQuery.isError) {
    return (
      <AppScaffold title={TITLE} showBackButton>
        <ErrorState message="Food categories could not be loaded." onRetry={() => categoriesQuery.refetch()} />
      </AppScaffold>
    );
  }

  const categories = categoriesQuery.data;
  if (categories.length === 0) {
    return (
      <AppScaffold title={TITLE} showBackButton>
        <EmptyState icon="category" title="No food categories are available yet." />
      </AppScaffold>
    );
  }

  return (
    <AppScaffold title={TITLE} showBackButton>
      <FlatList
        testID="food-categories-grid"
        data={categories}
        keyExtractor={(category) => category.id}
        numColumns={2}
        contentContainerStyle={{ padding: spacing.screenX, gap: spacing.gridGap }}
        columnWrapperStyle={{ gap: spacing.gridGap }}
        renderItem={({ item }) => (
          <View style={{ flex: 1 / 2 }}>
            <FoodCategoryCard category={item} onPress={() => openCategory(item)} />
          </View>
        )}
      />
    </AppScaffold>
  );
}

/** Mirrors `_FoodCategoriesScreenState._openCategory`. */
function openCategory(category: Category) {
  router.push(foodExplorePath({ categoryId: category.id, categoryName: category.name }) as never);
}

/**
 * One grid cell -- a white `OutlinedCard` (the service accent is confined
 * to the `ServiceIconChip`, as in Dart) with a two-line, centered name.
 * `minHeight` stands in for Dart's `childAspectRatio: 0.85` so a long,
 * wrapped name never clips.
 */
function FoodCategoryCard({ category, onPress }: { category: Category; onPress: () => void }) {
  return (
    <OutlinedCard
      testID={`food-category-card-${category.id}`}
      borderRadius={radius.tile}
      padding={spacing.x3}
      onPress={onPress}>
      <View style={{ minHeight: 140 }} className="items-center justify-center">
        <ServiceIconChip icon="restaurant-menu" size={40} borderRadius={radius.chip} service="food" />
        <View style={{ height: spacing.x2_5 }} />
        <Text numberOfLines={2} className="text-center text-fontBoldSm font-outfitSemiBold text-text">
          {category.name}
        </Text>
      </View>
    </OutlinedCard>
  );
}
