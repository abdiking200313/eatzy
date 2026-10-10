/**
 * Ports `flutter_app/lib/platform/discovery/presentation/explore_screen.dart`
 * (issue #375 / P4-04): the bottom-nav Explore tab -- a search + discovery
 * feed across all three verticals. Distinct from `../services.tsx` (a
 * simple vertical picker reached from the home grid's "More" tile), per
 * that Dart file's own doc comment.
 *
 * The Dart source also renders a food-category chip row sourced from
 * `CategoryRepository`, which has no react_native_app port yet (phase 6,
 * issue #385+) and isn't among this issue's own "Ports from Flutter"
 * files -- left out here. Every case in `explore_screen_test.dart` renders
 * this screen with an empty category list anyway, so the row would render
 * nothing either way; add it back once a real category data source exists.
 *
 * Mirrors `(tabs)/app.tsx`'s `storeListingLoader`-prop test-seam pattern.
 */
import { router } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { FlatList, Pressable, Text, View } from 'react-native';

import { AppScaffold } from '@/components/app-scaffold';
import { AppSearchBar } from '@/components/app-search-bar';
import { EmptyState } from '@/components/empty-state';
import { LoadingState } from '@/components/loading-state';
import { StoreListCard } from '@/components/store-list-card';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import type { StoreListing } from '@/platform/discovery/store-listing';
import { StoreListingRepository } from '@/platform/discovery/store-listing-repository';
import { forId, type ServiceId } from '@/theme/service-theme';
import { radius, spacing } from '@/theme/tokens';

/** `null` is the Dart `ServiceId? filter`'s "All" state. */
type ExploreFilter = ServiceId | null;

export type ExploreScreenProps = {
  /** Test seam mirroring the Dart `storeListingLoader` constructor param. */
  storeListingLoader?: (filter: ExploreFilter) => Promise<StoreListing[]>;
};

const defaultStoreListingLoader = (filter: ExploreFilter) =>
  new StoreListingRepository().fetchStores(filter ? { filter } : {});

type StoresState = { status: 'loading' } | { status: 'error' } | { status: 'data'; stores: StoreListing[] };

const FILTERS: { label: string; id: ExploreFilter }[] = [
  { label: 'All', id: null },
  { label: 'Food', id: 'food' },
  { label: 'Grocery', id: 'grocery' },
  { label: 'Pharmacy', id: 'pharmacy' },
];

export default function ExploreScreen({ storeListingLoader = defaultStoreListingLoader }: ExploreScreenProps = {}) {
  const [filter, setFilter] = useState<ExploreFilter>(null);
  const [query, setQuery] = useState('');
  const [storesState, setStoresState] = useState<StoresState>({ status: 'loading' });

  // Not a bare passthrough: wrapping in `.then`/`.catch` here (rather than
  // `await`ing in the effect below) keeps a synchronous throw from the
  // default loader's `new StoreListingRepository()` from escaping as an
  // unhandled render-time error -- mirrors the Dart source's own comment on
  // why `_loadStores` is `async`. Only ever called from the effect, with
  // `activeFilter` passed explicitly rather than closed over, so this
  // callback's own identity doesn't change when `filter` does (that would
  // re-run the effect for the wrong reason).
  const fetchStores = useCallback(
    (activeFilter: ExploreFilter) => {
      storeListingLoader(activeFilter)
        .then((stores) => setStoresState({ status: 'data', stores }))
        .catch(() => setStoresState({ status: 'error' }));
    },
    [storeListingLoader],
  );

  useEffect(() => {
    fetchStores(filter);
  }, [fetchStores, filter]);

  // The synchronous "back to loading" reset lives here, in a plain event
  // handler, rather than at the top of the effect above -- a lint rule
  // (react-hooks/set-state-in-effect) flags a synchronous `setState` call
  // in an effect body, since the effect dependency change below already
  // re-triggers `fetchStores` on its own.
  const selectFilter = useCallback(
    (id: ExploreFilter) => {
      if (id === filter) {
        return;
      }
      setStoresState({ status: 'loading' });
      setFilter(id);
    },
    [filter],
  );

  const stores = storesState.status === 'data' ? storesState.stores : [];
  const normalizedQuery = query.trim().toLowerCase();
  const filteredStores = normalizedQuery
    ? stores.filter((store) => store.name.toLowerCase().includes(normalizedQuery))
    : stores;

  return (
    <AppScaffold title="Explore" showBackButton={false}>
      <View style={{ paddingHorizontal: spacing.x5, paddingTop: 18 }}>
        <AppSearchBar hintText="Search restaurants, stores..." value={query} onChangeText={setQuery} />
      </View>
      <View style={{ marginTop: spacing.x4 }}>
        <FilterChipsRow selected={filter} onSelect={selectFilter} />
      </View>
      <View style={{ flex: 1, marginTop: spacing.x3 }}>
        {storesState.status === 'loading' ? (
          <LoadingState />
        ) : storesState.status === 'error' ? (
          <EmptyState icon="cloud-off" title="Stores could not be loaded." />
        ) : filteredStores.length === 0 ? (
          <EmptyState icon="storefront" title="No stores match your search." />
        ) : (
          <FlatList
            data={filteredStores}
            keyExtractor={(store) => store.id}
            contentContainerStyle={{ paddingHorizontal: spacing.x5, paddingBottom: spacing.x6 }}
            ItemSeparatorComponent={() => <View style={{ height: spacing.x3 }} />}
            renderItem={({ item }) => (
              <StoreListCard
                name={item.name}
                subtitle={item.subtitle}
                imageUrl={item.imageUrl}
                accentColor={forId(item.serviceId).accent}
                onPress={() => router.push(item.route as never)}
              />
            )}
          />
        )}
      </View>
    </AppScaffold>
  );
}

/** Ports `_FilterChipsRow`: horizontal `All / Food / Grocery / Pharmacy` chips controlling `StoreListingRepository.fetchStores`'s filter. */
function FilterChipsRow({ selected, onSelect }: { selected: ExploreFilter; onSelect: (filter: ExploreFilter) => void }) {
  const colors = useSemanticColors();

  return (
    <FlatList
      horizontal
      showsHorizontalScrollIndicator={false}
      data={FILTERS}
      keyExtractor={(item) => item.label}
      contentContainerStyle={{ paddingHorizontal: spacing.x5, gap: spacing.x2 }}
      renderItem={({ item }) => {
        const isSelected = item.id === selected;
        const accent = item.id === null ? colors.primary : forId(item.id).accent;
        // `soft` is this port's pre-computed pastel tint of `accent` --
        // stands in for the Dart `accent.withOpacityValue(0.14)` call
        // without needing hex/alpha math here.
        const background = item.id === null ? colors.primarySoft : forId(item.id).soft;
        return (
          <Pressable
            accessibilityRole="button"
            onPress={() => onSelect(item.id)}
            style={{
              height: 38,
              paddingHorizontal: spacing.x4,
              borderRadius: radius.full,
              borderWidth: 1,
              borderColor: isSelected ? accent : colors.border,
              backgroundColor: isSelected ? background : colors.card,
              justifyContent: 'center',
            }}>
            <Text
              style={{ color: isSelected ? accent : colors.textMuted }}
              className={isSelected ? 'text-textXs font-outfitBold' : 'text-textXs font-outfitMedium'}>
              {item.label}
            </Text>
          </Pressable>
        );
      }}
    />
  );
}
