/**
 * Ports `flutter_app/lib/services/pharmacy/presentation/pharmacy_product_details_screen.dart`'s
 * `PharmacyProductDetailsScreen` (issue #395 / P7-07): full-screen details
 * for one OTC product, reached by tapping its row in `PharmacyCatalogScreen`
 * or via a deep link to `/pharmacy/stores/:storeId/product/:productId`. A
 * thin wrapper around the shared `ProductDetailsView`.
 *
 * Like the Dart screen it only takes the two route ids and resolves the
 * product from the same catalog store `PharmacyCatalogScreen` reads
 * (`loadProducts({ storeId })`, a no-op when that store is already loaded
 * and fresh), so a cold deep link still resolves the product. As in Flutter
 * only the catalog's first page is loaded, so a deep link to a product past
 * that page shows "no longer available".
 *
 * Deviations (same as the grocery details port, #391): Flutter confirms
 * every add with `showCartSnackBar` on the app-wide messenger, which
 * survives the page popping. This app has no global snackbar host and
 * `ProductDetailsView` navigates back before calling `onAddToCart`, so a
 * successful add is conveyed by the cart badge on the catalog underneath,
 * and results where nothing was added are shown as a native alert. The
 * one-pharmacy-per-cart conflict dialog is a native alert too, as in
 * `pharmacy-catalog-screen.tsx`.
 */
import { MaterialIcons } from '@expo/vector-icons';
import { useEffect } from 'react';
import { Alert, Text, View } from 'react-native';

import { AppScaffold } from '@/components/app-scaffold';
import { LoadingState } from '@/components/loading-state';
import { ProductDetailsView } from '@/components/product-details-view';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { formatCents } from '@/platform/money/format';
import {
  isPharmacyProductAvailable,
  usePharmacyCartStore,
  type PharmacyCartAddResult,
  type PharmacyProduct,
} from '@/stores/pharmacy-cart-store';
import { spacing } from '@/theme/tokens';

import type { PharmacyCartStoreHook } from './pharmacy-cart-action';
import { pharmacyAddResultMessage, pharmacyStockLabel } from './pharmacy-catalog-screen';
import { defaultPharmacyCatalogStore, type PharmacyCatalogStore } from './pharmacy-catalog-store';

export const PHARMACY_OTC_FACT = 'Over the counter -- no prescription needed.';

export type PharmacyProductDetailsScreenProps = {
  storeId: string;
  productId: string;
  /** Test seam, mirroring the Dart widget's injectable `controller`. */
  catalogStore?: PharmacyCatalogStore;
  cartStore?: PharmacyCartStoreHook;
};

/** Mirrors the Dart `build`'s `remaining`: stock not already in the cart (0 when out of stock). */
export function pharmacyRemainingSteps(product: PharmacyProduct, inCart: number): number {
  return isPharmacyProductAvailable(product) ? product.stockQuantity - inCart : 0;
}

export function PharmacyProductDetailsScreen({
  storeId,
  productId,
  catalogStore,
  cartStore = usePharmacyCartStore,
}: PharmacyProductDetailsScreenProps) {
  const colors = useSemanticColors();
  const catalog = catalogStore ?? defaultPharmacyCatalogStore();
  const products = catalog((state) => state.products);
  const isLoading = catalog((state) => state.isLoading);
  const loadError = catalog((state) => state.loadError);
  const currentStoreId = catalog((state) => state.currentStoreId);
  const addProduct = cartStore((state) => state.addProduct);
  const inCart = cartStore((state) =>
    state.items.filter((item) => item.product.id === productId).reduce((total, item) => total + item.quantity, 0),
  );

  useEffect(() => {
    void catalog.getState().loadProducts({ storeId });
  }, [catalog, storeId]);

  const isThisStore = currentStoreId === storeId;
  const product = isThisStore ? (products.find((candidate) => candidate.id === productId) ?? null) : null;

  /** Mirrors `_addProduct`, including the cart-conflict dialog. */
  const add = (target: PharmacyProduct, quantity: number) => {
    const report = (result: PharmacyCartAddResult) => {
      if (result !== 'added' && result !== 'quantityIncreased') {
        Alert.alert(pharmacyAddResultMessage(result, target.name));
      }
    };
    const result = addProduct(target, { quantity });
    if (result !== 'storeConflict') {
      report(result);
      return;
    }
    Alert.alert(
      'Start a new pharmacy cart?',
      'Your pharmacy cart contains items from another pharmacy. Starting a cart here will remove them.',
      [
        { text: 'Keep cart', style: 'cancel' },
        { text: 'Start new cart', onPress: () => report(addProduct(target, { replaceStoreCart: true, quantity })) },
      ],
      { cancelable: true },
    );
  };

  if (!product) {
    // Before this store's first load settles, treat it as loading (the
    // Dart screen briefly showed "not found" in that window).
    const loading = isLoading || (!isThisStore && loadError == null);
    return (
      <AppScaffold title="Product" showBackButton>
        {loading ? (
          <LoadingState />
        ) : (
          <View className="flex-1 items-center justify-center" style={{ padding: spacing.x6 }}>
            <Text className="text-center text-textSm font-outfitRegular text-text">This product is no longer available.</Text>
          </View>
        )}
      </AppScaffold>
    );
  }

  const isAvailable = isPharmacyProductAvailable(product);

  return (
    <ProductDetailsView
      imageUrl={product.imageUrl}
      fallback={<MaterialIcons name="medication" size={96} color={colors.textMuted} />}
      eyebrow={product.category}
      name={product.name}
      priceLabel={formatCents(product.unitPrice)}
      stockLabel={pharmacyStockLabel(product)}
      isInStock={isAvailable}
      description={product.description}
      facts={[PHARMACY_OTC_FACT]}
      maxSteps={pharmacyRemainingSteps(product, inCart)}
      unavailableLabel={isAvailable ? 'All stock in cart' : 'Out of stock'}
      quantityLabel={(steps) => `${steps}`}
      onAddToCart={(quantity) => add(product, quantity)}
      service="pharmacy"
    />
  );
}
