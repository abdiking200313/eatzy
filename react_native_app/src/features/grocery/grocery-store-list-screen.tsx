/**
 * Ports `flutter_app/lib/services/grocery/presentation/grocery_screen.dart`'s
 * `GroceryScreen` (issue #389 / P7-01): the grocery/Fresh Meat/Electronics
 * store list -- pick a store first, then browse just that store's products
 * (a later issue builds the store-scoped catalog screen this navigates to).
 *
 * Grocery, Fresh Meat and Electronics all render this same component with a
 * different `storeType`, mirroring the Dart widget's own `storeType`
 * constructor parameter -- see `grocery-store-type-meta.ts` for the
 * per-type title/route/palette lookup.
 *
 * Uses the injected-loader test seam `explore.tsx` established (issue
 * #375) rather than TanStack Query, so a test can assert on the store list
 * deterministically without mocking the query cache.
 */
import { router } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { FlatList, RefreshControl, Text, View } from 'react-native';

import { AppScaffold } from '@/components/app-scaffold';
import { AppSearchBar } from '@/components/app-search-bar';
import { CartAppBarAction } from '@/components/cart-app-bar-action';
import { EmptyState } from '@/components/empty-state';
import { ErrorState } from '@/components/error-state';
import { LoadingState } from '@/components/loading-state';
import { StoreRowCard } from '@/components/store-row-card';
import { groceryCartStoreFor, type GroceryStoreType } from '@/stores/grocery-cart-store';
import { spacing } from '@/theme/tokens';

import { fetchGroceryStores } from './api/grocery-repository';
import type { GroceryStore } from './api/grocery-store';
import { GROCERY_STORE_TYPE_META } from './grocery-store-type-meta';

export type GroceryStoreListScreenProps = {
  storeType: GroceryStoreType;
  /** Test seam mirroring `explore.tsx`'s `storeListingLoader` prop. */
  storesLoader?: () => Promise<GroceryStore[]>;
};

type LoadState = { status: 'loading' } | { status: 'error'; message: string } | { status: 'data'; stores: GroceryStore[] };

export function GroceryStoreListScreen({ storeType, storesLoader = fetchGroceryStores }: GroceryStoreListScreenProps) {
  const meta = GROCERY_STORE_TYPE_META[storeType];
  const [query, setQuery] = useState('');
  const [state, setState] = useState<LoadState>({ status: 'loading' });
  const [refreshing, setRefreshing] = useState(false);
  const itemCount = groceryCartStoreFor(storeType).store((s) => s.lines.length);

  // Wrapped in `.then`/`.catch` rather than `await`ed directly -- same
  // reasoning as `explore.tsx`'s `fetchStores`: keeps a synchronous throw
  // from the default loader from escaping as an unhandled render-time
  // error.
  const load = useCallback(() => {
    storesLoader()
      .then((stores) => setState({ status: 'data', stores: stores.filter((store) => store.storeType === storeType) }))
      .catch(() => setState({ status: 'error', message: `${meta.title} could not be loaded. Please try again.` }));
  }, [storesLoader, storeType, meta.title]);

  useEffect(() => {
    load();
  }, [load]);

  const refresh = useCallback(async () => {
    setRefreshing(true);
    await storesLoader()
      .then((stores) => setState({ status: 'data', stores: stores.filter((store) => store.storeType === storeType) }))
      .catch(() => setState({ status: 'error', message: `${meta.title} could not be loaded. Please try again.` }));
    setRefreshing(false);
  }, [storesLoader, storeType, meta.title]);

  const stores = state.status === 'data' ? state.stores : [];
  const normalizedQuery = query.trim().toLowerCase();
  const visibleStores = normalizedQuery ? stores.filter((store) => store.name.toLowerCase().includes(normalizedQuery)) : stores;

  const openStore = (store: GroceryStore) => router.push(meta.storeDetailsRoute(store.id) as never);

  return (
    <AppScaffold
      title={meta.title}
      showBackButton
      actions={
        <CartAppBarAction
          itemCount={itemCount}
          onPress={() => router.push(meta.cartRoute as never)}
          tooltip={`${meta.serviceName} cart (${itemCount})`}
          icon="shopping-basket"
          service="grocery"
          slug={meta.slug}
        />
      }>
      {state.status === 'loading' ? (
        <LoadingState />
      ) : state.status === 'error' ? (
        <ErrorState message={state.message} onRetry={load} />
      ) : (
        <FlatList
          testID="grocery-store-list"
          data={visibleStores}
          keyExtractor={(store) => store.id}
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={refresh} />}
          contentContainerStyle={{ paddingHorizontal: spacing.x5, paddingTop: spacing.x2, paddingBottom: spacing.x6 }}
          ListHeaderComponent={
            <View style={{ marginBottom: spacing.x5 }}>
              <Text className="text-textXl font-outfitBold text-text">Somali stores near you</Text>
              <View style={{ height: spacing.x2 }} />
              <Text className="text-textSm font-outfitRegular text-textMuted">Pick a store to browse its products.</Text>
              <View style={{ height: spacing.x5 }} />
              <AppSearchBar hintText="Search stores..." value={query} onChangeText={setQuery} />
            </View>
          }
          ItemSeparatorComponent={() => <View style={{ height: spacing.x3 }} />}
          ListEmptyComponent={
            <EmptyState
              icon="storefront"
              title={normalizedQuery ? `No stores match "${query.trim()}".` : `No ${meta.storesNoun} found yet.`}
            />
          }
          renderItem={({ item }) => (
            <StoreRowCard
              imageUrl={item.imageUrl}
              fallbackIcon="storefront"
              name={item.name}
              subtitleLines={[item.area]}
              caption={`${item.products.length} ${item.products.length === 1 ? 'product' : 'products'}`}
              onPress={() => openStore(item)}
              service="grocery"
              slug={meta.slug}
            />
          )}
        />
      )}
    </AppScaffold>
  );
}
