/**
 * Ports `flutter_app/lib/services/pharmacy/presentation/pharmacy_store_list_screen.dart`
 * (`PharmacyStoreListScreen`, issue #394 / P7-06): the pharmacy vertical's
 * entry screen -- a searchable list of pharmacies a customer picks from
 * before browsing a single pharmacy's OTC catalog.
 *
 * Same seams as the Dart widget: `storeLoader` (the unfiltered list) and
 * `storeQuery` (the debounced, server-side name search) both default to
 * `fetchPharmacyStores`, and either can be injected by a test.
 */
import { router } from 'expo-router';
import { useCallback, useEffect, useRef, useState } from 'react';
import { FlashList } from '@shopify/flash-list';
import { ActivityIndicator, Text, View } from 'react-native';

import { AppScaffold } from '@/components/app-scaffold';
import { AppSearchBar } from '@/components/app-search-bar';
import { ErrorState } from '@/components/error-state';
import { LoadingState } from '@/components/loading-state';
import { StoreRowCard } from '@/components/store-row-card';
import { pharmacyStoreDetails } from '@/platform/navigation/app-routes';
import { spacing } from '@/theme/tokens';

import { fetchPharmacyStores } from './api/pharmacy-repository';
import type { PharmacyStore } from './api/pharmacy-models';
import { PharmacyCartAction, type PharmacyCartStoreHook } from './pharmacy-cart-action';

/** Mirrors `_searchDebounce` (`Duration(milliseconds: 400)`). */
export const PHARMACY_SEARCH_DEBOUNCE_MS = 400;

export type PharmacyStoreLoader = () => Promise<PharmacyStore[]>;
export type PharmacyStoreQuery = (searchQuery: string) => Promise<PharmacyStore[]>;

export type PharmacyStoreListScreenProps = {
  storeLoader?: PharmacyStoreLoader;
  storeQuery?: PharmacyStoreQuery;
  /** Defaults to the app-wide pharmacy cart store -- injectable so a test can use an isolated one. */
  cartStore?: PharmacyCartStoreHook;
  /** Overrides {@link PHARMACY_SEARCH_DEBOUNCE_MS} -- mainly for tests. */
  debounceMs?: number;
};

type LoadState<T> = { status: 'loading' } | { status: 'error' } | { status: 'data'; data: T };

const LOAD_ERROR_MESSAGE = 'Pharmacies could not be loaded.';

/**
 * Builds the catalog location `_openStore` pushes: the store's name and
 * (when present) photo ride along as query params so the catalog screen's
 * app bar/hero doesn't need its own fetch.
 */
export function pharmacyCatalogLocation(store: PharmacyStore): string {
  const params = [`name=${encodeURIComponent(store.name)}`];
  if (store.imageUrl != null) {
    params.push(`photoUrl=${encodeURIComponent(store.imageUrl)}`);
  }
  return `${pharmacyStoreDetails(store.id)}?${params.join('&')}`;
}

const defaultLoader: PharmacyStoreLoader = () => fetchPharmacyStores();
const defaultQuery: PharmacyStoreQuery = (searchQuery) => fetchPharmacyStores(searchQuery);

export function PharmacyStoreListScreen({
  storeLoader = defaultLoader,
  storeQuery = defaultQuery,
  cartStore,
  debounceMs = PHARMACY_SEARCH_DEBOUNCE_MS,
}: PharmacyStoreListScreenProps) {
  const [stores, setStores] = useState<LoadState<PharmacyStore[]>>({ status: 'loading' });
  const [searchText, setSearchText] = useState('');
  /** Non-null once a search term has been applied -- replaces the unfiltered list until cleared. Mirrors `_filteredStores`. */
  const [filtered, setFiltered] = useState<{ query: string; state: LoadState<PharmacyStore[]> } | null>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const searchGeneration = useRef(0);

  const load = useCallback(() => {
    // `.then`/`.catch` rather than `await` so a synchronous throw from an
    // injected loader can't escape as a render-time error -- same as
    // `grocery-store-list-screen.tsx`.
    Promise.resolve()
      .then(storeLoader)
      .then((data) => setStores({ status: 'data', data }))
      .catch(() => setStores({ status: 'error' }));
  }, [storeLoader]);

  useEffect(() => {
    load();
  }, [load]);

  const retry = () => {
    setStores({ status: 'loading' });
    load();
  };

  useEffect(
    () => () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    },
    [],
  );

  /** Mirrors `_buildFilteredStores`: `null` filter for an empty search box, otherwise a fresh query. */
  const applySearch = useCallback(
    (text: string) => {
      const generation = ++searchGeneration.current;
      const query = text.trim();
      if (!query) {
        setFiltered(null);
        return;
      }
      setFiltered({ query, state: { status: 'loading' } });
      Promise.resolve()
        .then(() => storeQuery(query))
        .then((data) => {
          if (generation === searchGeneration.current) setFiltered({ query, state: { status: 'data', data } });
        })
        .catch(() => {
          if (generation === searchGeneration.current) setFiltered({ query, state: { status: 'error' } });
        });
    },
    [storeQuery],
  );

  const onSearchChanged = (text: string) => {
    setSearchText(text);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => applySearch(text), debounceMs);
  };

  const clearSearch = () => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    setSearchText('');
    applySearch('');
  };

  const openStore = (store: PharmacyStore) => router.push(pharmacyCatalogLocation(store) as never);

  const listState: LoadState<PharmacyStore[]> | null = filtered ? filtered.state : stores.status === 'data' ? stores : null;
  const visibleStores = listState?.status === 'data' ? listState.data : [];

  const renderEmpty = () => {
    if (listState?.status === 'loading') {
      return (
        <View style={{ padding: spacing.x8, alignItems: 'center' }}>
          <ActivityIndicator />
        </View>
      );
    }
    const message =
      listState?.status === 'error'
        ? LOAD_ERROR_MESSAGE
        : filtered
          ? `No pharmacies match "${filtered.query}".`
          : 'No pharmacies found.';
    return (
      <View style={{ padding: spacing.x8, alignItems: 'center' }}>
        <Text className="text-textSm font-outfitRegular text-text">{message}</Text>
      </View>
    );
  };

  return (
    <AppScaffold title="Pharmacy" showBackButton actions={<PharmacyCartAction cartStore={cartStore} />}>
      {stores.status === 'loading' ? (
        <LoadingState />
      ) : stores.status === 'error' ? (
        <ErrorState message={LOAD_ERROR_MESSAGE} onRetry={retry} />
      ) : (
        <FlashList
          testID="pharmacy-store-list"
          data={visibleStores}
          keyExtractor={(store) => store.id}
          keyboardShouldPersistTaps="handled"
          contentContainerStyle={{ paddingHorizontal: spacing.screenX, paddingTop: spacing.screenX, paddingBottom: spacing.x6 }}
          ListHeaderComponent={
            <View>
              <AppSearchBar
                hintText="Search pharmacies..."
                value={searchText}
                onChangeText={onSearchChanged}
                onClear={clearSearch}
              />
              <View style={{ height: spacing.sectionGap }} />
              <Text className="text-sectionTitle font-outfitSemiBold text-text">Pharmacies near you</Text>
              <View style={{ height: spacing.headerToContent }} />
            </View>
          }
          ItemSeparatorComponent={StoreSeparator}
          ListEmptyComponent={renderEmpty}
          renderItem={({ item }) => (
            <StoreRowCard
              imageUrl={item.imageUrl}
              fallbackIcon="local-pharmacy"
              name={item.name}
              subtitleLines={item.address ? [item.address] : []}
              subtitleMaxLines={2}
              onPress={() => openStore(item)}
              service="pharmacy"
            />
          )}
        />
      )}
    </AppScaffold>
  );
}

/** Hoisted so the list keeps one stable separator component across renders (issue #417). */
function StoreSeparator() {
  return <View style={{ height: spacing.x3 }} />;
}
