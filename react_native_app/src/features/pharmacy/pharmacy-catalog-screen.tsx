/**
 * Ports `flutter_app/lib/services/pharmacy/presentation/pharmacy_catalog_screen.dart`
 * (`PharmacyCatalogScreen`, issue #394 / P7-06): a single pharmacy's OTC
 * product catalog, reached by picking a pharmacy on the store list first,
 * so browsing (and the cart it feeds) is always scoped to one pharmacy.
 *
 * Catalog state comes from `pharmacy-catalog-store.ts` (the ported
 * `PharmacyController.loadProducts`/`loadMore`); the cart from
 * `pharmacy-cart-store.ts`. Both are injectable for tests, mirroring the
 * Dart widget's injectable `controller`.
 *
 * One deliberate rendering difference from the Dart source: products
 * loaded for a *different* pharmacy (the shared catalog store's previous
 * scope) are never shown while this pharmacy's first load is in flight --
 * the loading state shows instead. The Dart screen briefly rendered the
 * previous pharmacy's rows in that window.
 */
import { router } from 'expo-router';
import { useCallback, useEffect, useRef, useState } from 'react';
import { FlashList } from '@shopify/flash-list';
import { ActivityIndicator, Alert, RefreshControl, Text, View } from 'react-native';

import { AddToCartButton } from '@/components/add-to-cart-button';
import { AppScaffold } from '@/components/app-scaffold';
import { AppSearchBar } from '@/components/app-search-bar';
import { CartSnackbar } from '@/components/cart-snackbar';
import { ErrorState } from '@/components/error-state';
import { LoadingState } from '@/components/loading-state';
import { OutlinedCard } from '@/components/outlined-card';
import { PhotoThumbnail } from '@/components/photo-thumbnail';
import { ServiceIconChip } from '@/components/service-icon-chip';
import { StatusPill } from '@/components/status-pill';
import { StoreHeroAppBar } from '@/components/store-hero-app-bar';
import { useCartSnackbar } from '@/hooks/use-cart-snackbar';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { formatCents } from '@/platform/money/format';
import { AppRoutes, pharmacyProductDetails } from '@/platform/navigation/app-routes';
import {
  isPharmacyProductAvailable,
  isPharmacyProductLowStock,
  usePharmacyCartStore,
  type PharmacyCartAddResult,
  type PharmacyProduct,
} from '@/stores/pharmacy-cart-store';
import { spacing } from '@/theme/tokens';

import { PharmacyCartAction, type PharmacyCartStoreHook } from './pharmacy-cart-action';
import { defaultPharmacyCatalogStore, type PharmacyCatalogStore } from './pharmacy-catalog-store';
import { PHARMACY_SEARCH_DEBOUNCE_MS } from './pharmacy-store-list-screen';

export type PharmacyCatalogScreenProps = {
  /** The pharmacy (`PharmacyStore.id`) this catalog is scoped to. */
  storeId: string;
  /** Passed through from the store list so the app bar needs no fetch; falls back to "Pharmacy" (e.g. a bare deep link). */
  storeName?: string | null;
  /** The pharmacy's photo, passed through the same way. */
  storeImageUrl?: string | null;
  catalogStore?: PharmacyCatalogStore;
  cartStore?: PharmacyCartStoreHook;
  /** Overrides {@link PHARMACY_SEARCH_DEBOUNCE_MS} -- mainly for tests. */
  debounceMs?: number;
};

/** Mirrors `_addProduct`'s per-result snackbar copy. */
export function pharmacyAddResultMessage(result: PharmacyCartAddResult, productName: string): string {
  switch (result) {
    case 'added':
      return `${productName} added to pharmacy cart.`;
    case 'quantityIncreased':
      return `${productName} quantity increased.`;
    case 'notOverTheCounter':
      return `${productName} is not eligible for OTC ordering.`;
    case 'unavailable':
      return `${productName} is currently out of stock.`;
    case 'maximumStockReached':
      return `You already have all available ${productName} in your cart.`;
    case 'storeConflict':
      return 'Your pharmacy cart was kept unchanged.';
  }
}

/** Mirrors `_ProductCard`'s stock label. */
export function pharmacyStockLabel(product: PharmacyProduct): string {
  if (!isPharmacyProductAvailable(product)) return 'Out of stock';
  if (isPharmacyProductLowStock(product)) return `Only ${product.stockQuantity} left`;
  return 'In stock';
}

export function PharmacyCatalogScreen({
  storeId,
  storeName,
  storeImageUrl,
  catalogStore,
  cartStore = usePharmacyCartStore,
  debounceMs = PHARMACY_SEARCH_DEBOUNCE_MS,
}: PharmacyCatalogScreenProps) {
  const catalog = catalogStore ?? defaultPharmacyCatalogStore();
  const products = catalog((state) => state.products);
  const isLoading = catalog((state) => state.isLoading);
  const isLoadingMore = catalog((state) => state.isLoadingMore);
  const hasMore = catalog((state) => state.hasMore);
  const loadError = catalog((state) => state.loadError);
  const currentStoreId = catalog((state) => state.currentStoreId);
  const addProduct = cartStore((state) => state.addProduct);

  const [searchText, setSearchText] = useState('');
  const [refreshing, setRefreshing] = useState(false);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const snackbar = useCartSnackbar();

  const title = storeName || 'Pharmacy';
  const isThisStore = currentStoreId === storeId;
  const visibleProducts = isThisStore ? products : [];

  // Clears the search box when the screen is reused for another pharmacy
  // (Dart's `didUpdateWidget`) -- adjusted during render rather than in an
  // effect, per React's "adjusting state when a prop changes" pattern.
  const [searchStoreId, setSearchStoreId] = useState(storeId);
  if (searchStoreId !== storeId) {
    setSearchStoreId(storeId);
    setSearchText('');
  }

  useEffect(() => {
    void catalog.getState().loadProducts({ storeId });
  }, [catalog, storeId]);

  useEffect(
    () => () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    },
    [],
  );

  const onSearchChanged = (text: string) => {
    setSearchText(text);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => {
      void catalog.getState().loadProducts({ storeId, searchQuery: text, forceRefresh: true });
    }, debounceMs);
  };

  const clearSearch = () => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    setSearchText('');
    void catalog.getState().loadProducts({ storeId, forceRefresh: true });
  };

  const refresh = useCallback(async () => {
    setRefreshing(true);
    await catalog.getState().loadProducts({ storeId, searchQuery: searchText, forceRefresh: true });
    setRefreshing(false);
  }, [catalog, storeId, searchText]);

  const retry = () => {
    void catalog.getState().loadProducts({ storeId });
  };

  const addToCart = (product: PharmacyProduct) => {
    const result = addProduct(product);
    if (result === 'storeConflict') {
      Alert.alert(
        'Start a new pharmacy cart?',
        'Your pharmacy cart contains items from another pharmacy. Starting a cart here will remove them.',
        [
          { text: 'Keep cart', style: 'cancel' },
          {
            text: 'Start new cart',
            onPress: () => {
              const replaced = addProduct(product, { replaceStoreCart: true });
              snackbar.show(pharmacyAddResultMessage(replaced, product.name));
            },
          },
        ],
      );
      return;
    }
    snackbar.show(pharmacyAddResultMessage(result, product.name));
  };

  const cartAction = <PharmacyCartAction cartStore={cartStore} />;

  // The hero only appears once the catalog has something to show (or at
  // least isn't in its initial loading/error state) -- mirrors the Dart
  // `build`'s two early returns.
  if (visibleProducts.length === 0 && (isLoading || (!isThisStore && loadError == null))) {
    return (
      <AppScaffold title={title} showBackButton actions={cartAction}>
        <LoadingState />
      </AppScaffold>
    );
  }
  if (loadError != null && visibleProducts.length === 0) {
    return (
      <AppScaffold title={title} showBackButton actions={cartAction}>
        <ErrorState message={loadError} onRetry={retry} />
      </AppScaffold>
    );
  }

  const trimmedSearch = searchText.trim();
  const emptyMessage = trimmedSearch
    ? `No products match "${trimmedSearch}" at this pharmacy.`
    : 'This pharmacy has no OTC products yet.';

  return (
    <View style={{ flex: 1 }}>
      <StoreHeroAppBar
        title={title}
        imageUrl={storeImageUrl}
        fallbackIcon="storefront"
        showBackButton
        onBackPress={() => (router.canGoBack() ? router.back() : router.replace(AppRoutes.mainApp))}
        service="pharmacy"
        actions={cartAction}
      />
      <FlashList
        testID="pharmacy-catalog-list"
        data={visibleProducts}
        keyExtractor={(product) => product.id}
        keyboardShouldPersistTaps="handled"
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={refresh} />}
        contentContainerStyle={{ padding: spacing.screenX }}
        onEndReached={() => {
          if (hasMore) void catalog.getState().loadMore();
        }}
        ListHeaderComponent={
          <View>
            <View style={{ paddingBottom: spacing.x3_5 }}>
              <AppSearchBar
                hintText="Search this pharmacy..."
                value={searchText}
                onChangeText={onSearchChanged}
                onClear={clearSearch}
              />
            </View>
            <View style={{ paddingBottom: spacing.x3_5 }}>
              <OtcNotice />
            </View>
            <View style={{ paddingBottom: spacing.x3_5 }}>
              <Text className="text-sectionTitle font-outfitSemiBold text-text">Health essentials</Text>
              <View style={{ height: spacing.x1 }} />
              <Text className="text-textSm font-outfitRegular text-text">
                Seeded products for the interactive Zivo preview.
              </Text>
            </View>
          </View>
        }
        ItemSeparatorComponent={ProductSeparator}
        ListEmptyComponent={
          isLoading ? null : (
            <View style={{ paddingTop: spacing.x8, alignItems: 'center' }}>
              <Text className="text-textSm font-outfitRegular text-text">{emptyMessage}</Text>
            </View>
          )
        }
        ListFooterComponent={
          hasMore ? (
            <View style={{ paddingTop: spacing.x4, alignItems: 'center' }}>
              {isLoadingMore ? <ActivityIndicator testID="pharmacy-catalog-loading-more" /> : <View style={{ height: spacing.x8 }} />}
            </View>
          ) : (
            <View style={{ height: spacing.x6 }} />
          )
        }
        renderItem={({ item }) => (
          <PharmacyProductCard
            product={item}
            onAdd={() => addToCart(item)}
            onPress={() => router.push(pharmacyProductDetails(storeId, item.id) as never)}
          />
        )}
      />
      <CartSnackbar message={snackbar.message} />
    </View>
  );
}

/** Ports `_OtcNotice`. */
function OtcNotice() {
  return (
    <OutlinedCard padding={spacing.x4}>
      <View className="flex-row items-start">
        <ServiceIconChip icon="health-and-safety" service="pharmacy" />
        <View style={{ width: spacing.x3_5 }} />
        <View style={{ flex: 1 }}>
          <Text className="text-fontBoldSm font-outfitSemiBold text-text">Over-the-counter (OTC) only</Text>
          <View style={{ height: 3 }} />
          <Text className="text-textXs font-outfitMedium text-text">
            This preview does not accept prescriptions or include regulated medicines. Ask a healthcare professional if you
            are unsure which product is right for you.
          </Text>
        </View>
      </View>
    </OutlinedCard>
  );
}

/** Stands in for the Dart `Color.withOpacityValue` on the in-stock pill -- same private helper `product-details-view.tsx` carries. */
function withAlpha(hex: string, alpha: number): string {
  const value = hex.replace('#', '');
  const r = parseInt(value.slice(0, 2), 16);
  const g = parseInt(value.slice(2, 4), 16);
  const b = parseInt(value.slice(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

/** Ports `_ProductCard`. */
function PharmacyProductCard({
  product,
  onAdd,
  onPress,
}: {
  product: PharmacyProduct;
  onAdd: () => void;
  onPress: () => void;
}) {
  const colors = useSemanticColors();
  const available = isPharmacyProductAvailable(product);
  const stockLabel = pharmacyStockLabel(product);

  return (
    <OutlinedCard padding={spacing.x4} onPress={onPress} testID={`pharmacy-product-${product.id}`}>
      <View className="flex-row items-start">
        <PhotoThumbnail
          imageUrl={product.imageUrl}
          size={60}
          fallback={<ServiceIconChip icon="medication" iconSize={28} size={60} service="pharmacy" />}
        />
        <View style={{ width: spacing.x3_5 }} />
        <View style={{ flex: 1 }}>
          <Text className="text-link font-outfitSemiBold text-primary">{product.category}</Text>
          <View style={{ height: spacing.x2 }} />
          <Text className="text-fontBoldBase font-outfitSemiBold text-text">{product.name}</Text>
          <View style={{ height: 3 }} />
          <Text className="text-textSm font-outfitRegular text-text">{product.description}</Text>
          <View style={{ height: spacing.x3_5 }} />
          <View className="flex-row flex-wrap items-center" style={{ columnGap: spacing.x3, rowGap: spacing.x2 }}>
            <Text className="text-fontBoldBase font-outfitSemiBold text-primary">{formatCents(product.unitPrice)}</Text>
            <StatusPill
              label={stockLabel}
              backgroundColor={available ? withAlpha(colors.tertiary, 0.14) : colors.errorSoft}
              foregroundColor={available ? '#0F7A54' : colors.error}
            />
          </View>
        </View>
        <View style={{ width: spacing.x2 }} />
        <AddToCartButton tooltip={available ? `Add ${product.name}` : stockLabel} onPress={available ? onAdd : null} />
      </View>
    </OutlinedCard>
  );
}

/** Hoisted so the list keeps one stable separator component across renders (issue #417). */
function ProductSeparator() {
  return <View style={{ height: spacing.x3 }} />;
}
