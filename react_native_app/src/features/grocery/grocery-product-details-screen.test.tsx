/**
 * Ports the details-page half of `flutter_app/test/grocery_screens_test.dart`'s
 * "tapping a product opens its details page, which adds the picked weight
 * to the cart" (issue #391 / P7-03). The navigation half (tapping a row
 * pushes the per-store-type details route) is ported in
 * `grocery-store-screen.test.tsx`; here the screen is rendered directly
 * with an injected `storeLoader`, the same seam that file uses.
 *
 * The rest covers `GroceryProductDetailsScreen`'s own behavior the Dart
 * test file never asserts directly: loading/error/not-found states, the
 * stock-aware quantity cap, the one-store-per-cart conflict prompt, and
 * per-store-type carts.
 */
import { fireEvent, waitFor } from '@testing-library/react-native';
import { router } from 'expo-router';
import { Alert } from 'react-native';

import { groceryCartStores, type GroceryProduct } from '@/stores/grocery-cart-store';
import { renderWithProviders } from '@/test-utils';

import type { GroceryStore } from './api/grocery-store';
import { GroceryProductDetailsScreen, groceryMaxSteps, groceryStepsLabel } from './grocery-product-details-screen';

jest.mock('expo-router', () => ({
  router: {
    push: jest.fn(),
    canGoBack: jest.fn(() => false),
    back: jest.fn(),
    replace: jest.fn(),
  },
}));

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

function product(overrides: Partial<GroceryProduct> & Pick<GroceryProduct, 'id' | 'name'>): GroceryProduct {
  return {
    storeId: 'bakaal-fresh',
    description: '',
    unitPrice: 100,
    pricingUnit: 'each',
    stockState: 'inStock',
    availableQuantity: 10,
    icon: '🛒',
    imageUrl: null,
    categoryName: null,
    categorySortOrder: 0,
    ...overrides,
  };
}

// Mirrors `SeededGroceryRepository`'s Bakaal Fresh store.
const bananas = product({
  id: 'bakaal-bananas',
  name: 'Bananas',
  description: 'Fresh bananas, sold by weight',
  unitPrice: 180,
  pricingUnit: 'kilogram',
  availableQuantity: 12,
  icon: '🍌',
});
const rice = product({ id: 'bakaal-rice', name: 'Basmati rice', description: 'One 5 kg bag', unitPrice: 850, availableQuantity: 2 });

const bakaalFresh: GroceryStore = {
  id: 'bakaal-fresh',
  name: 'Bakaal Fresh',
  area: 'Hodan, Mogadishu',
  imageUrl: null,
  storeType: 'grocery',
  products: [bananas, rice],
};

const loaderFor = (store: GroceryStore | null) => jest.fn(async () => store);

beforeEach(() => {
  jest.clearAllMocks();
  for (const handle of Object.values(groceryCartStores)) {
    handle.store.getState().clearInMemory();
  }
});

describe('GroceryProductDetailsScreen', () => {
  it('adds the picked weight of a by-weight product to the grocery cart', async () => {
    const loader = loaderFor(bakaalFresh);
    const { getByText, getByLabelText } = await renderWithProviders(
      <GroceryProductDetailsScreen storeId="bakaal-fresh" productId="bakaal-bananas" storeLoader={loader} />,
    );

    await waitFor(() => expect(getByText('Bananas')).toBeOnTheScreen());
    expect(loader).toHaveBeenCalledWith('bakaal-fresh');
    expect(getByText('$1.80 per kg')).toBeOnTheScreen();
    expect(getByText('In stock')).toBeOnTheScreen();
    expect(getByText('Sold by weight, in 0.5 kg steps.')).toBeOnTheScreen();
    expect(getByText('0.5 kg')).toBeOnTheScreen();

    await fireEvent.press(getByLabelText('Increase quantity'));
    expect(getByText('1 kg')).toBeOnTheScreen();

    await fireEvent.press(getByText('Add to cart'));

    expect(router.back).toHaveBeenCalled();
    const lines = groceryCartStores.grocery.store.getState().lines;
    expect(lines).toHaveLength(1);
    expect(lines[0].product.id).toBe('bakaal-bananas');
    expect(lines[0].quantity).toBe(1);
  });

  it('caps the quantity picker at the stock not already in the cart', async () => {
    groceryCartStores.grocery.store.getState().addProduct(rice);
    const { getByText, getByLabelText } = await renderWithProviders(
      <GroceryProductDetailsScreen storeId="bakaal-fresh" productId="bakaal-rice" storeLoader={loaderFor(bakaalFresh)} />,
    );

    await waitFor(() => expect(getByText('Basmati rice')).toBeOnTheScreen());
    expect(getByText('$8.50 each')).toBeOnTheScreen();
    expect(getByLabelText('Increase quantity')).toBeDisabled();

    await fireEvent.press(getByText('Add to cart'));
    expect(groceryCartStores.grocery.store.getState().lines[0].quantity).toBe(2);
  });

  it('shows "All stock in cart" once everything is in the cart', async () => {
    groceryCartStores.grocery.store.getState().addProduct(rice, { steps: 2 });
    const { getByText } = await renderWithProviders(
      <GroceryProductDetailsScreen storeId="bakaal-fresh" productId="bakaal-rice" storeLoader={loaderFor(bakaalFresh)} />,
    );
    await waitFor(() => expect(getByText('All stock in cart')).toBeOnTheScreen());
  });

  it('shows "Out of stock" for an unavailable product', async () => {
    const soldOut: GroceryStore = { ...bakaalFresh, products: [{ ...bananas, stockState: 'outOfStock', availableQuantity: 0 }] };
    const { getAllByText } = await renderWithProviders(
      <GroceryProductDetailsScreen storeId="bakaal-fresh" productId="bakaal-bananas" storeLoader={loaderFor(soldOut)} />,
    );
    // Both the stock pill and the disabled Add to cart button.
    await waitFor(() => expect(getAllByText('Out of stock')).toHaveLength(2));
  });

  it('adds to the cart of its own store type', async () => {
    const butcher: GroceryStore = { ...bakaalFresh, storeType: 'fresh_meat' };
    const { getByText } = await renderWithProviders(
      <GroceryProductDetailsScreen
        storeId="bakaal-fresh"
        productId="bakaal-rice"
        storeType="fresh_meat"
        storeLoader={loaderFor(butcher)}
      />,
    );

    await waitFor(() => expect(getByText('Basmati rice')).toBeOnTheScreen());
    await fireEvent.press(getByText('Add to cart'));

    expect(groceryCartStores.fresh_meat.store.getState().lines).toHaveLength(1);
    expect(groceryCartStores.grocery.store.getState().lines).toHaveLength(0);
  });

  it('prompts before replacing a cart from another store', async () => {
    const other = product({ id: 'hamar-eggs', name: 'Eggs', storeId: 'suuqa-hamar' });
    groceryCartStores.grocery.store.getState().addProduct(other);
    const alertSpy = jest.spyOn(Alert, 'alert');
    const { getByText } = await renderWithProviders(
      <GroceryProductDetailsScreen storeId="bakaal-fresh" productId="bakaal-rice" storeLoader={loaderFor(bakaalFresh)} />,
    );

    await waitFor(() => expect(getByText('Basmati rice')).toBeOnTheScreen());
    await fireEvent.press(getByText('Add to cart'));

    expect(alertSpy).toHaveBeenCalledWith('Start a new store cart?', expect.any(String), expect.any(Array), expect.anything());
    expect(groceryCartStores.grocery.store.getState().lines[0].product.id).toBe('hamar-eggs');

    const buttons = alertSpy.mock.calls[0][2] as { text: string; onPress?: () => void }[];
    buttons.find((button) => button.text === 'Replace cart')?.onPress?.();

    const lines = groceryCartStores.grocery.store.getState().lines;
    expect(lines).toHaveLength(1);
    expect(lines[0].product.id).toBe('bakaal-rice');
  });

  it('shows the not-found state for a product missing from the store', async () => {
    const { getByText } = await renderWithProviders(
      <GroceryProductDetailsScreen storeId="bakaal-fresh" productId="gone" storeLoader={loaderFor(bakaalFresh)} />,
    );
    await waitFor(() => expect(getByText('This product is no longer available.')).toBeOnTheScreen());
    expect(getByText('Product')).toBeOnTheScreen();
  });

  it('shows an error with a retry that reloads the store', async () => {
    const loader = jest.fn().mockRejectedValueOnce(new Error('offline')).mockResolvedValueOnce(bakaalFresh);
    const { getByText, getByTestId } = await renderWithProviders(
      <GroceryProductDetailsScreen storeId="bakaal-fresh" productId="bakaal-bananas" storeLoader={loader} />,
    );

    await waitFor(() => expect(getByTestId('error-state')).toBeOnTheScreen());
    await fireEvent.press(getByText('Try again'));
    await waitFor(() => expect(getByText('Bananas')).toBeOnTheScreen());
    expect(loader).toHaveBeenCalledTimes(2);
  });
});

describe('groceryMaxSteps / groceryStepsLabel', () => {
  it('counts the remaining whole steps, tolerating float error', () => {
    expect(groceryMaxSteps({ ...bananas, availableQuantity: 2.5 }, 0)).toBe(5);
    expect(groceryMaxSteps(bananas, 11.5)).toBe(1);
    expect(groceryMaxSteps({ ...bananas, stockState: 'outOfStock' }, 0)).toBe(0);
  });

  it('labels weights in kg and counts as plain numbers', () => {
    expect(groceryStepsLabel(bananas, 1)).toBe('0.5 kg');
    expect(groceryStepsLabel(bananas, 2)).toBe('1 kg');
    expect(groceryStepsLabel(bananas, 3)).toBe('1.5 kg');
    expect(groceryStepsLabel(rice, 3)).toBe('3');
  });
});
