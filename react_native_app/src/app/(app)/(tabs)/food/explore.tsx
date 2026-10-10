/**
 * Ports `flutter_app/lib/services/food/presentation/food_explore_screen.dart`'s
 * `FoodExploreScreen` (issue #385): the food restaurant list -- heading,
 * blurb, an instant client-side name filter, and a flat list of
 * `StoreRowCard`s, each opening that restaurant's menu.
 *
 * Reads the optional `?categoryId=&categoryName=` query params, mirroring
 * `app_router.dart`'s `foodExplore` route (set by tapping a card on
 * `/food/categories`, see `foodExplorePath`): `categoryId` narrows the
 * server-side query to restaurants with a menu item in that category, and
 * `categoryName` replaces the default "Explore restaurants" title.
 *
 * Data comes from `useFoodExploreRestaurants(categoryId)`
 * (`use-food-browse.ts`), a `useQuery` over the existing `fetchRestaurants`
 * repository function. The search box filters the loaded list locally (no
 * debounce, no refetch), exactly like Dart's `_visibleRestaurants`.
 *
 * Deviation from the Dart source: loading/error/empty chrome reuses
 * `LoadingState`/`ErrorState`/`EmptyState` (same convention as
 * `food/index.tsx`) instead of the bespoke `_FoodExploreMessage`; copy is
 * preserved, and the error view gains a "Try again" retry button.
 */
import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { FlatList, Text, View } from 'react-native';

import { AppScaffold } from '@/components/app-scaffold';
import { AppSearchBar } from '@/components/app-search-bar';
import { EmptyState } from '@/components/empty-state';
import { ErrorState } from '@/components/error-state';
import { LoadingState } from '@/components/loading-state';
import { StoreRowCard } from '@/components/store-row-card';
import type { Restaurant } from '@/features/food/api/restaurant';
import { useFoodExploreRestaurants } from '@/features/food/api/use-food-browse';
import { restaurantDetails } from '@/platform/navigation/app-routes';
import { spacing } from '@/theme/tokens';

type ExploreSearchParams = { categoryId?: string | string[]; categoryName?: string | string[] };

/** Expo Router may hand back a repeated query param as an array; take the first, and treat blank as absent. */
function singleParam(value: string | string[] | undefined): string | null {
  const first = Array.isArray(value) ? value[0] : value;
  return first && first.length > 0 ? first : null;
}

export default function FoodExploreScreen() {
  const params = useLocalSearchParams<ExploreSearchParams>();
  const categoryId = singleParam(params.categoryId);
  const categoryName = singleParam(params.categoryName);
  const title = categoryName ?? 'Explore restaurants';

  const restaurantsQuery = useFoodExploreRestaurants(categoryId);
  const [searchQuery, setSearchQuery] = useState('');

  if (restaurantsQuery.isPending) {
    return (
      <AppScaffold title={title} showBackButton>
        <LoadingState />
      </AppScaffold>
    );
  }

  if (restaurantsQuery.isError) {
    return (
      <AppScaffold title={title} showBackButton>
        <ErrorState message="Restaurants could not be loaded." onRetry={() => restaurantsQuery.refetch()} />
      </AppScaffold>
    );
  }

  const allRestaurants = restaurantsQuery.data;
  if (allRestaurants.length === 0) {
    return (
      <AppScaffold title={title} showBackButton>
        <EmptyState
          icon="restaurant"
          title={categoryId == null ? 'No restaurants are available yet.' : 'No restaurants found in this category.'}
        />
      </AppScaffold>
    );
  }

  const trimmedQuery = searchQuery.trim();
  const restaurants = visibleRestaurants(allRestaurants, trimmedQuery);

  return (
    <AppScaffold title={title} showBackButton>
      <FlatList
        testID="food-explore-list"
        data={restaurants}
        keyExtractor={(restaurant) => restaurant.id}
        keyboardShouldPersistTaps="handled"
        contentContainerStyle={{
          paddingHorizontal: spacing.screenX,
          paddingTop: spacing.x2,
          paddingBottom: spacing.x6,
        }}
        ListHeaderComponent={
          <View style={{ paddingBottom: spacing.x5 }}>
            <Text className="text-sectionTitle font-outfitSemiBold text-text">Restaurants near you</Text>
            <View style={{ height: spacing.x2 }} />
            <Text className="text-textSm font-outfitRegular text-textMuted">Pick a restaurant to browse its menu.</Text>
            <View style={{ height: spacing.x5 }} />
            <AppSearchBar hintText="Search restaurants..." value={searchQuery} onChangeText={setSearchQuery} />
          </View>
        }
        ListEmptyComponent={
          <View style={{ paddingVertical: spacing.x8 }}>
            <Text className="text-center text-textSm font-outfitRegular text-textMuted">
              {`No restaurants match "${trimmedQuery}".`}
            </Text>
          </View>
        }
        ItemSeparatorComponent={() => <View style={{ height: spacing.x3 }} />}
        renderItem={({ item }) => (
          <StoreRowCard
            imageUrl={item.logoUrl}
            fallbackIcon="restaurant"
            name={item.name}
            subtitleLines={item.description.trim() ? [item.description] : []}
            onPress={() => router.push(restaurantDetails(item.id) as never)}
            service="food"
          />
        )}
      />
    </AppScaffold>
  );
}

/** Mirrors `_FoodExploreScreenState._visibleRestaurants`: a case-insensitive name substring match. */
function visibleRestaurants(restaurants: Restaurant[], trimmedQuery: string): Restaurant[] {
  const query = trimmedQuery.toLowerCase();
  if (!query) return restaurants;
  return restaurants.filter((restaurant) => restaurant.name.toLowerCase().includes(query));
}
