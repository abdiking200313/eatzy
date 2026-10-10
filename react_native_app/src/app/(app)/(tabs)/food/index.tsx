/**
 * Ports `flutter_app/lib/services/food/presentation/food_home_screen.dart`'s
 * `FoodHomeScreen` (issue #382): the food tab's home screen -- a search
 * bar, the horizontal category-chip rail, and the restaurant list, which
 * swaps to a server-side search/category-filtered list once a search term
 * is typed and/or a category chip is selected.
 *
 * Data loading itself is a sibling issue's work, consumed here as-is:
 * `useFoodHome()` (the unfiltered `{categories, restaurants}`, mirrors
 * `CatalogQueries.foodHome()`) and `useFoodRestaurantSearch()` (the
 * debounced, server-side filtered query, mirrors
 * `_buildFilteredRestaurants`/`_searchDebounce`). This screen only owns the
 * search `<TextInput>` value and the selected category id, passing both
 * into `useFoodRestaurantSearch` on every render -- see that hook's own
 * top comment for the one documented clear-button timing deviation from
 * the Dart source.
 *
 * Loading/error chrome for the *first* load (no cached data at all) reuses
 * this app's generic `LoadingState`/`ErrorState` components (see
 * `src/app/(app)/(tabs)/explore.tsx` for the same convention) rather than
 * re-building the Dart source's bespoke `_FoodHomeError` card -- the retry
 * affordance and copy are preserved, but the icon (`ErrorState`'s fixed
 * `error-outline`, vs. Dart's `cloud_off_outlined`) and the plain (not
 * card-wrapped) chrome differ.
 */
import { router } from 'expo-router';
import { useState } from 'react';
import { ActivityIndicator, FlatList, Text, View } from 'react-native';

import { CartAppBarAction } from '@/components/cart-app-bar-action';
import { CategoriesSection } from '@/components/categories-section';
import { AppScaffold } from '@/components/app-scaffold';
import { AppSearchBar } from '@/components/app-search-bar';
import { ErrorState } from '@/components/error-state';
import { LoadingState } from '@/components/loading-state';
import { SectionHeader } from '@/components/section-header';
import { StoreRowCard } from '@/components/store-row-card';
import { useFoodHome } from '@/features/food/api/use-food-home';
import { useFoodRestaurantSearch } from '@/features/food/api/use-food-restaurant-search';
import type { Restaurant } from '@/features/food/api/restaurant';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { AppRoutes, restaurantDetails } from '@/platform/navigation/app-routes';
import { selectFoodCartItemCount, useFoodCartStore } from '@/stores/food-cart-store';
import { spacing } from '@/theme/tokens';

export default function FoodHomeScreen() {
  const home = useFoodHome();
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategoryId, setSelectedCategoryId] = useState<string | null>(null);
  const search = useFoodRestaurantSearch({ searchQuery, categoryId: selectedCategoryId });
  const cartItemCount = useFoodCartStore((state) => selectFoodCartItemCount(state.items));
  const colors = useSemanticColors();

  const data = home.data;

  // Tapping the already-selected chip clears the filter -- mirrors
  // `_selectCategory`.
  const selectCategory = (categoryId: string) => {
    setSelectedCategoryId((current) => (current === categoryId ? null : categoryId));
  };

  const openRestaurant = (restaurant: Restaurant) => router.push(restaurantDetails(restaurant.id) as never);

  // Cached data wins over both the first-load spinner and a failed
  // background refresh; the error view only shows when nothing was ever
  // cached -- mirrors the Dart `StreamBuilder`'s `initialData`/`hasError`
  // precedence.
  if (!data) {
    if (home.isError) {
      return (
        <AppScaffold title="Food" showBackButton>
          <ErrorState message="Food options could not be loaded." onRetry={() => home.refetch()} />
        </AppScaffold>
      );
    }

    return (
      <AppScaffold title="Food" showBackButton>
        <LoadingState />
      </AppScaffold>
    );
  }

  const restaurants = search.isActive ? search.restaurants : data.restaurants;
  const isRestaurantsLoading = search.isActive && search.isLoading;
  const isRestaurantsError = search.isActive && search.isError;

  return (
    <AppScaffold
      title="Food"
      showBackButton
      actions={
        <CartAppBarAction
          itemCount={cartItemCount}
          tooltip={`Food cart (${cartItemCount})`}
          onPress={() => router.push(AppRoutes.foodCart as never)}
          service="food"
        />
      }>
      <FlatList
        testID="food-restaurant-list"
        data={restaurants}
        keyExtractor={(restaurant) => restaurant.id}
        contentContainerStyle={{ paddingBottom: spacing.x6 }}
        ListHeaderComponent={
          <View>
            <View style={{ paddingHorizontal: spacing.screenX, paddingTop: 18 }}>
              <AppSearchBar
                hintText="Search restaurants..."
                value={searchQuery}
                onChangeText={setSearchQuery}
              />
            </View>
            <View style={{ height: spacing.sectionGapDense }} />
            <View style={{ paddingHorizontal: spacing.screenX }}>
              <SectionHeader
                title="Categories"
                actionLabel="See All"
                onPress={() => router.push(AppRoutes.foodCategories as never)}
              />
            </View>
            <View style={{ height: spacing.headerToContent }} />
            <CategoriesSection
              categories={data.categories}
              selectedCategoryId={selectedCategoryId}
              onCategorySelected={selectCategory}
            />
            <View style={{ height: spacing.sectionGapDense }} />
            <View style={{ paddingHorizontal: spacing.screenX }}>
              <SectionHeader
                title="Trending Now"
                actionLabel="View All"
                onPress={() => router.push(AppRoutes.foodExplore as never)}
              />
            </View>
            <View style={{ height: spacing.headerToContent }} />
          </View>
        }
        ListEmptyComponent={
          <View style={{ paddingHorizontal: spacing.screenX, paddingVertical: spacing.x8 }}>
            {isRestaurantsLoading ? (
              <View className="items-center">
                <ActivityIndicator color={colors.primary} />
              </View>
            ) : (
              <Text className="text-center text-textBase font-outfitRegular text-textMuted">
                {isRestaurantsError ? 'Restaurants could not be loaded.' : emptyMessage(searchQuery, selectedCategoryId)}
              </Text>
            )}
          </View>
        }
        ItemSeparatorComponent={() => <View style={{ height: spacing.x4 }} />}
        renderItem={({ item }) => (
          <View style={{ paddingHorizontal: spacing.screenX }}>
            <StoreRowCard
              imageUrl={item.logoUrl}
              fallbackIcon="restaurant"
              name={item.name}
              subtitleLines={item.description.trim() ? [item.description] : []}
              onPress={() => openRestaurant(item)}
              service="food"
            />
          </View>
        )}
      />
    </AppScaffold>
  );
}

/** Mirrors `_FoodHomeScreenState._emptyFilterMessage`/the unfiltered empty copy in `_buildRestaurantResults`. */
function emptyMessage(searchQuery: string, selectedCategoryId: string | null): string {
  const trimmedQuery = searchQuery.trim();
  const hasCategory = selectedCategoryId != null;

  if (!trimmedQuery && !hasCategory) {
    return 'No restaurants found.';
  }
  if (trimmedQuery && hasCategory) {
    return `No restaurants match "${trimmedQuery}" in this category.`;
  }
  if (trimmedQuery) {
    return `No restaurants match "${trimmedQuery}".`;
  }
  return 'No restaurants found in this category.';
}
