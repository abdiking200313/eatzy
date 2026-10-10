/**
 * Ports `flutter_app/lib/services/grocery/presentation/grocery_product_details_screen.dart`'s
 * `GroceryProductDetailsScreen` (issue #391 / P7-03): the full-screen
 * details page for one grocery product, reached by tapping its row in
 * `GroceryStoreScreen` or via a deep link to
 * `/grocery/stores/:storeId/product/:productId` (or its Fresh Meat/
 * Electronics siblings). A thin wrapper around the shared
 * `ProductDetailsView`.
 *
 * Like the Dart screen it only takes the two route ids and loads the
 * product itself through the same store-scoped load `GroceryStoreScreen`
 * uses (`fetchGroceryStore`, the port of `GroceryController.loadStore`), so
 * a cold deep link still resolves the product. `storeLoader` is the same
 * injected test seam as `grocery-store-screen.tsx`.
 *
 * Deviation: the Dart screen confirms every add with `showCartSnackBar`,
 * which lives on the app-wide `ScaffoldMessenger` and so survives the page
 * popping. This app has no global snackbar host yet (see `useCartSnackbar`)
 * and `ProductDetailsView` navigates back before calling `onAddToCart`, so
 * -- as in the food `MenuItemDetailsScreen` port -- a successful add is
 * conveyed by the cart badge on the store screen underneath. Results where
 * nothing was added ("out of stock", "no more available") are shown as a
 * native alert (app-wide) so they are not lost. The one-store-per-cart
 * conflict dialog is a native alert too, as in `grocery-store-screen.tsx`.
 */
import { useCallback, useEffect, useState } from 'react';
import { Alert, Text, View } from 'react-native';

import { AppScaffold } from '@/components/app-scaffold';
import { ErrorState } from '@/components/error-state';
import { groceryStockLabel, groceryUnitLabel } from '@/components/grocery-product-card';
import { LoadingState } from '@/components/loading-state';
import { ProductDetailsView } from '@/components/product-details-view';
import { formatCents } from '@/platform/money/format';
import {
  groceryCartStoreFor,
  groceryQuantityStep,
  isGroceryProductAvailable,
  type GroceryAddResult,
  type GroceryProduct,
  type GroceryStoreType,
} from '@/stores/grocery-cart-store';
import { spacing } from '@/theme/tokens';

import { fetchGroceryStore } from './api/grocery-repository';
import type { GroceryStore } from './api/grocery-store';
import { groceryAddMessage } from './grocery-store-screen';
import { GROCERY_STORE_TYPE_META } from './grocery-store-type-meta';

export type GroceryProductDetailsScreenProps = {
  storeId: string;
  productId: string;
  /** Which category's cart/palette this product uses. Mirrors the Dart `storeType` (default `grocery`). */
  storeType?: GroceryStoreType;
  /** Test seam mirroring `grocery-store-screen.tsx`'s `storeLoader` prop. */
  storeLoader?: (storeId: string) => Promise<GroceryStore | null>;
};

type LoadState = { status: 'loading' } | { status: 'error'; message: string } | { status: 'data'; store: GroceryStore | null };

const LOAD_ERROR_MESSAGE = 'This store could not be loaded. Please try again.';

/**
 * Mirrors `_GroceryProductDetailsScreenState.build`'s `maxSteps`: how many
 * quantity steps can still be added (stock minus what's already in the
 * cart), with a small tolerance against float error (e.g. 2.5 / 0.5).
 */
export function groceryMaxSteps(product: GroceryProduct, inCart: number): number {
  const remaining = isGroceryProductAvailable(product) ? product.availableQuantity - inCart : 0;
  return Math.floor(remaining / groceryQuantityStep(product.pricingUnit) + 1e-9);
}

/** Mirrors the Dart `quantityLabel` callback: a step count, or a weight like "1.5 kg". */
export function groceryStepsLabel(product: GroceryProduct, steps: number): string {
  if (product.pricingUnit !== 'kilogram') {
    return `${steps}`;
  }
  const kg = steps * groceryQuantityStep(product.pricingUnit);
  return `${kg} kg`;
}

export function GroceryProductDetailsScreen({
  storeId,
  productId,
  storeType = 'grocery',
  storeLoader = fetchGroceryStore,
}: GroceryProductDetailsScreenProps) {
  const meta = GROCERY_STORE_TYPE_META[storeType];
  const cart = groceryCartStoreFor(storeType).store;
  const addProduct = cart((state) => state.addProduct);
  const inCart = cart((state) =>
    state.lines.filter((line) => line.product.id === productId).reduce((total, line) => total + line.quantity, 0),
  );

  const [state, setState] = useState<LoadState>({ status: 'loading' });

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

  /** Mirrors `_GroceryProductDetailsScreenState._add`, including the cart-conflict dialog. */
  const add = (product: GroceryProduct, steps: number) => {
    const report = (result: GroceryAddResult) => {
      if (result === 'unavailable' || result === 'stockLimitReached') {
        Alert.alert(groceryAddMessage(result, product.name));
      }
    };
    const result = addProduct(product, { steps });
    if (result !== 'storeConflict') {
      report(result);
      return;
    }
    Alert.alert(
      'Start a new store cart?',
      'The grocery MVP keeps one store per checkout. Your current grocery cart will be replaced.',
      [
        { text: 'Keep current cart', style: 'cancel' },
        {
          text: 'Replace cart',
          onPress: () => report(addProduct(product, { replaceStoreCart: true, steps })),
        },
      ],
      { cancelable: true },
    );
  };

  const product = state.status === 'data' ? (state.store?.products.find((candidate) => candidate.id === productId) ?? null) : null;

  if (!product) {
    return (
      <AppScaffold title="Product" showBackButton>
        {state.status === 'loading' ? (
          <LoadingState />
        ) : state.status === 'error' ? (
          <ErrorState message={state.message} onRetry={retry} />
        ) : (
          <View className="flex-1 items-center justify-center" style={{ padding: spacing.x6 }}>
            <Text className="text-center text-textSm font-outfitRegular text-text">This product is no longer available.</Text>
          </View>
        )}
      </AppScaffold>
    );
  }

  const isAvailable = isGroceryProductAvailable(product);

  return (
    <ProductDetailsView
      imageUrl={product.imageUrl}
      fallback={<Text style={{ fontSize: 96 }}>{product.icon}</Text>}
      name={product.name}
      priceLabel={`${formatCents(product.unitPrice)} ${groceryUnitLabel(product)}`}
      stockLabel={groceryStockLabel(product.stockState)}
      isInStock={isAvailable}
      description={product.description}
      facts={product.pricingUnit === 'kilogram' ? ['Sold by weight, in 0.5 kg steps.'] : []}
      maxSteps={groceryMaxSteps(product, inCart)}
      unavailableLabel={isAvailable ? 'All stock in cart' : 'Out of stock'}
      quantityLabel={(steps) => groceryStepsLabel(product, steps)}
      onAddToCart={(steps) => add(product, steps)}
      service="grocery"
      slug={meta.slug}
    />
  );
}
