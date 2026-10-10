/**
 * Ports `flutter_app/lib/services/grocery/presentation/grocery_store_screen.dart`'s
 * `GroceryStoreScreen` (issue #390 / P7-02): a single store's product
 * catalog, reached by tapping a store on the store list -- only this
 * store's products, grouped into category sections, searchable by product
 * name, with the one-store-per-cart conflict prompt on add.
 *
 * Grocery, Fresh Meat and Electronics all render this same component with
 * a different `storeType` (which cart it adds to, which cart/product routes
 * it links to, which accent it uses) -- mirrors the Dart widget's own
 * `storeType` constructor parameter.
 *
 * Uses the same injected-loader test seam as `grocery-store-list-screen.tsx`
 * (issue #389): `storeLoader` defaults to `fetchGroceryStore`, the port of
 * `GroceryController.loadStore`/`GroceryCatalog.loadStore` (one store and
 * only its own products -- never the full multi-store catalog).
 *
 * Like `RestaurantMenuScreen`, the hero (`StoreHeroAppBar`) is a fixed
 * header above the list rather than the Dart collapsing `SliverAppBar` --
 * see that component's own doc comment.
 */
import { router } from 'expo-router';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { Alert, FlatList, RefreshControl, Text, View } from 'react-native';

import { AppScaffold } from '@/components/app-scaffold';
import { AppSearchBar } from '@/components/app-search-bar';
import { CartAppBarAction } from '@/components/cart-app-bar-action';
import { CartSnackbar } from '@/components/cart-snackbar';
import { ErrorState } from '@/components/error-state';
import { GroceryProductCard } from '@/components/grocery-product-card';
import { LoadingState } from '@/components/loading-state';
import { StoreHeroAppBar } from '@/components/store-hero-app-bar';
import { useCartSnackbar } from '@/hooks/use-cart-snackbar';
import { groceryCartStoreFor, type GroceryAddResult, type GroceryProduct, type GroceryStoreType } from '@/stores/grocery-cart-store';
import { spacing } from '@/theme/tokens';

import { fetchGroceryStore } from './api/grocery-repository';
import type { GroceryStore } from './api/grocery-store';
import { filterProductsByName, groupByCategory } from './grocery-catalog';
import { GROCERY_STORE_TYPE_META } from './grocery-store-type-meta';

export type GroceryStoreScreenProps = {
  storeId: string;
  /** Which category's cart this store adds to. Mirrors the Dart `storeType` (default `grocery`). */
  storeType?: GroceryStoreType;
  /** Test seam mirroring `grocery-store-list-screen.tsx`'s `storesLoader` prop. */
  storeLoader?: (storeId: string) => Promise<GroceryStore | null>;
};

type LoadState = { status: 'loading' } | { status: 'error'; message: string } | { status: 'data'; store: GroceryStore | null };

type CatalogRow =
  | { kind: 'sectionHeader'; key: string; name: string; count: number }
  | { kind: 'sectionSpacer'; key: string }
  | { kind: 'product'; key: string; product: GroceryProduct; isFirstInSection: boolean };

const LOAD_ERROR_MESSAGE = 'This store could not be loaded. Please try again.';

/** Mirrors `_add`'s per-result snackbar copy. */
export function groceryAddMessage(result: GroceryAddResult, productName: string): string {
  switch (result) {
    case 'added':
      return `${productName} added to your grocery cart.`;
    case 'quantityIncreased':
      return `${productName} quantity increased.`;
    case 'unavailable':
      return `${productName} is out of stock.`;
    case 'stockLimitReached':
      return `No more ${productName} is available.`;
    case 'storeConflict':
      return 'Your current grocery cart was kept.';
  }
}

export function GroceryStoreScreen({ storeId, storeType = 'grocery', storeLoader = fetchGroceryStore }: GroceryStoreScreenProps) {
  const meta = GROCERY_STORE_TYPE_META[storeType];
  const cart = groceryCartStoreFor(storeType).store;
  const itemCount = cart((state) => state.lines.length);
  const addProduct = cart((state) => state.addProduct);

  const [state, setState] = useState<LoadState>({ status: 'loading' });
  const [refreshing, setRefreshing] = useState(false);
  const [query, setQuery] = useState('');
  const snackbar = useCartSnackbar();

  // `.then`/`.catch` rather than `await` -- same reasoning as
  // `grocery-store-list-screen.tsx`'s `load`.
  const load = useCallback(() => {
    storeLoader(storeId)
      .then((store) => setState({ status: 'data', store }))
      .catch(() => setState({ status: 'error', message: LOAD_ERROR_MESSAGE }));
  }, [storeLoader, storeId]);

  useEffect(() => {
    load();
  }, [load]);

  const retry = useCallback(() => {
    setState({ status: 'loading' });
    load();
  }, [load]);

  // A failed pull-to-refresh keeps the already-loaded store on screen,
  // mirroring the Dart screen gating on `hasLoadedStore` (which stays true
  // after a later failed reload) rather than on `loadError`.
  const refresh = useCallback(async () => {
    setRefreshing(true);
    await storeLoader(storeId)
      .then((store) => setState({ status: 'data', store }))
      .catch(() => undefined);
    setRefreshing(false);
  }, [storeLoader, storeId]);

  const store = state.status === 'data' ? state.store : null;
  const products = useMemo(() => (store ? filterProductsByName(store.products, query) : []), [store, query]);
  const rows = useMemo(() => buildRows(products), [products]);

  const add = useCallback(
    (product: GroceryProduct) => {
      const result = addProduct(product);
      if (result !== 'storeConflict') {
        snackbar.show(groceryAddMessage(result, product.name));
        return;
      }
      Alert.alert(
        'Start a new store cart?',
        'The grocery MVP keeps one store per checkout. Your current grocery cart will be replaced.',
        [
          { text: 'Keep current cart', style: 'cancel', onPress: () => snackbar.show(groceryAddMessage('storeConflict', product.name)) },
          {
            text: 'Replace cart',
            onPress: () => snackbar.show(groceryAddMessage(addProduct(product, { replaceStoreCart: true }), product.name)),
          },
        ],
        { cancelable: true, onDismiss: () => snackbar.show(groceryAddMessage('storeConflict', product.name)) },
      );
    },
    [addProduct, snackbar],
  );

  const cartAction = (
    <CartAppBarAction
      itemCount={itemCount}
      onPress={() => router.push(meta.cartRoute as never)}
      tooltip={`${meta.serviceName} cart (${itemCount})`}
      icon="shopping-basket"
      service="grocery"
      slug={meta.slug}
    />
  );

  // The hero needs a loaded store (for its name/photo), so the loading,
  // error and "not found" states fall back to the plain title bar --
  // same as the Dart screen.
  if (!store) {
    return (
      <AppScaffold title="Store" showBackButton actions={cartAction}>
        {state.status === 'loading' ? (
          <LoadingState />
        ) : state.status === 'error' ? (
          <ErrorState message={state.message} onRetry={retry} />
        ) : (
          <View className="flex-1 items-center justify-center" style={{ padding: spacing.x6 }}>
            <Text className="text-center text-textSm font-outfitRegular text-text">This store could not be found.</Text>
          </View>
        )}
      </AppScaffold>
    );
  }

  const trimmedQuery = query.trim();

  return (
    <View style={{ flex: 1 }}>
      <StoreHeroAppBar
        title={store.name}
        imageUrl={store.imageUrl}
        fallbackIcon="storefront"
        showBackButton
        onBackPress={() => (router.canGoBack() ? router.back() : router.replace('/'))}
        service="grocery"
        slug={meta.slug}
        actions={cartAction}
      />
      <FlatList
        testID="grocery-store-catalog"
        data={rows}
        keyExtractor={(row) => row.key}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={refresh} />}
        keyboardShouldPersistTaps="handled"
        contentContainerStyle={{ paddingHorizontal: spacing.screenX, paddingTop: spacing.screenX, paddingBottom: spacing.x6 }}
        ListHeaderComponent={
          <View>
            <Text className="text-textSm font-outfitRegular text-text">{store.area}</Text>
            <View style={{ height: spacing.x2 }} />
            <Text className="text-textSm font-outfitRegular text-text">Products marked per kg can be added in 0.5 kg steps.</Text>
            <View style={{ height: spacing.x5 }} />
            <AppSearchBar hintText="Search products..." value={query} onChangeText={setQuery} onClear={() => setQuery('')} />
          </View>
        }
        ListEmptyComponent={
          <View style={{ paddingVertical: spacing.x8 }} className="items-center">
            <Text className="text-center text-textSm font-outfitRegular text-text">
              {trimmedQuery.length === 0 ? 'This store has no products yet.' : `No products match "${trimmedQuery}".`}
            </Text>
          </View>
        }
        renderItem={({ item: row }) => {
          switch (row.kind) {
            case 'sectionSpacer':
              return <View style={{ height: spacing.headerToContent }} />;
            case 'sectionHeader':
              return (
                <View
                  testID={`grocery-category-${row.name}`}
                  style={{ paddingTop: spacing.sectionGap, paddingBottom: spacing.headerToContent }}
                  className="flex-row items-baseline">
                  <Text style={{ flex: 1 }} className="text-sectionTitle font-outfitBold text-text">
                    {row.name}
                  </Text>
                  <Text className="text-textXs font-outfitMedium text-textMuted">{`${row.count} ${row.count === 1 ? 'item' : 'items'}`}</Text>
                </View>
              );
            case 'product':
              return (
                <View style={{ paddingTop: row.isFirstInSection ? 0 : spacing.x3 }}>
                  <GroceryProductCard
                    product={row.product}
                    slug={meta.slug}
                    onAdd={() => add(row.product)}
                    onPress={() => router.push(meta.productDetailsRoute(storeId, row.product.id) as never)}
                  />
                </View>
              );
          }
        }}
      />
      <CartSnackbar message={snackbar.message} />
    </View>
  );
}

/**
 * Flattens the category sections into list rows. A lone section (an
 * uncategorised store, or a search that only matches one category) gets no
 * header -- the list then looks as it did before categories existed --
 * mirrors `_StoreView`'s `showSectionHeaders`.
 */
function buildRows(products: GroceryProduct[]): CatalogRow[] {
  const sections = groupByCategory(products);
  const showSectionHeaders = sections.length > 1;
  return sections.flatMap((section): CatalogRow[] => [
    showSectionHeaders
      ? { kind: 'sectionHeader', key: `header-${section.name}`, name: section.name, count: section.products.length }
      : { kind: 'sectionSpacer', key: `spacer-${section.name}` },
    ...section.products.map((product, index) => ({
      kind: 'product' as const,
      key: `product-${product.id}`,
      product,
      isFirstInSection: index === 0,
    })),
  ]);
}
