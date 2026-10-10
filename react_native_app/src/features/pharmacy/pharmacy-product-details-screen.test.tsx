/**
 * Ports the details-page half of `flutter_app/test/pharmacy_screens_test.dart`'s
 * "tapping a product opens its details page, which adds the picked quantity
 * to the cart" (issue #395 / P7-07). The navigation half (tapping a row
 * pushes the product-details route) is ported in
 * `pharmacy-catalog-screen.test.tsx` (#394); here the screen is rendered
 * directly against an isolated catalog store over the seeded repository.
 *
 * The rest covers `PharmacyProductDetailsScreen`'s own behavior the Dart
 * test file never asserts directly: loading/not-found states, the
 * stock-aware quantity cap, out-of-stock products, and the
 * one-pharmacy-per-cart conflict prompt.
 */
import { act, fireEvent, waitFor } from '@testing-library/react-native';
import { router } from 'expo-router';
import { Alert } from 'react-native';

import { createPharmacyCartStore, type PharmacyProduct } from '@/stores/pharmacy-cart-store';
import { SessionResetRegistry } from '@/stores/session-reset-registry';
import { renderWithProviders } from '@/test-utils';
import { MemoryCartStorage } from '@/test-utils/memory-cart-storage';

import { createInMemoryPharmacyRepository, SEEDED_PHARMACY_STORE_ID } from './api/pharmacy-repository';
import { createPharmacyCatalogStore } from './pharmacy-catalog-store';
import { PharmacyProductDetailsScreen } from './pharmacy-product-details-screen';

jest.mock('expo-router', () => ({
  router: { push: jest.fn(), back: jest.fn(), replace: jest.fn(), canGoBack: jest.fn(() => true) },
}));

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

function buildStores(repository = createInMemoryPharmacyRepository()) {
  const catalogStore = createPharmacyCatalogStore({ repository });
  const cartStore = createPharmacyCartStore({ storage: new MemoryCartStorage(), registry: new SessionResetRegistry() }).store;
  return { catalogStore, cartStore };
}

function renderDetails(productId: string, stores = buildStores(), storeId = SEEDED_PHARMACY_STORE_ID) {
  return renderWithProviders(
    <PharmacyProductDetailsScreen
      storeId={storeId}
      productId={productId}
      catalogStore={stores.catalogStore}
      cartStore={stores.cartStore}
    />,
  );
}

beforeEach(() => {
  jest.clearAllMocks();
  jest.spyOn(Alert, 'alert').mockImplementation(() => {});
});

afterEach(() => {
  jest.restoreAllMocks();
});

describe('PharmacyProductDetailsScreen', () => {
  it('adds the picked quantity to the pharmacy cart', async () => {
    const stores = buildStores();
    const { getByText, getByLabelText } = await renderDetails('pain-paracetamol', stores);

    await waitFor(() => expect(getByText('Paracetamol')).toBeOnTheScreen());
    expect(getByText('Everyday relief for mild pain and fever.')).toBeOnTheScreen();
    expect(getByText('Pain relief')).toBeOnTheScreen();
    expect(getByText('$2.75')).toBeOnTheScreen();
    expect(getByText('In stock')).toBeOnTheScreen();
    expect(getByText('Over the counter -- no prescription needed.')).toBeOnTheScreen();

    await fireEvent.press(getByLabelText('Increase quantity'));
    await fireEvent.press(getByLabelText('Increase quantity'));
    expect(getByText('3')).toBeOnTheScreen();

    await fireEvent.press(getByText('Add to cart'));

    expect(router.back).toHaveBeenCalled();
    const items = stores.cartStore.getState().items;
    expect(items).toHaveLength(1);
    expect(items[0].product.id).toBe('pain-paracetamol');
    expect(items[0].quantity).toBe(3);
    expect(Alert.alert).not.toHaveBeenCalled();
  });

  it('caps the quantity picker at the stock not already in the cart', async () => {
    const stores = buildStores();
    const { getByText, getByLabelText } = await renderDetails('cold-cough-syrup', stores);
    await waitFor(() => expect(getByText('Only 4 left')).toBeOnTheScreen());
    const syrup = stores.catalogStore.getState().products.find((p) => p.id === 'cold-cough-syrup')!;
    await act(async () => {
      stores.cartStore.getState().addProduct(syrup, { quantity: 3 });
    });

    await waitFor(() => expect(getByLabelText('Increase quantity')).toBeDisabled());
    await fireEvent.press(getByText('Add to cart'));
    expect(stores.cartStore.getState().items[0].quantity).toBe(4);
  });

  it('shows an out-of-stock product without letting it be added', async () => {
    const { getAllByText, queryByText } = await renderDetails('allergy-antihistamine');

    // The stock pill and the disabled button both read "Out of stock".
    await waitFor(() => expect(getAllByText('Out of stock')).toHaveLength(2));
    expect(queryByText('Add to cart')).toBeNull();
  });

  it('shows a not-found message for a product that no longer resolves', async () => {
    const { findByText } = await renderDetails('missing-product');

    expect(await findByText('This product is no longer available.')).toBeOnTheScreen();
  });

  it('asks before replacing a cart from another pharmacy, and replaces it on confirm', async () => {
    const stores = buildStores();
    const other: PharmacyProduct = {
      id: 'other-item',
      storeId: 'other-pharmacy',
      name: 'Other item',
      description: '',
      category: 'General',
      unitPrice: 100,
      stockQuantity: 5,
      saleType: 'overTheCounter',
    };
    stores.cartStore.getState().addProduct(other);
    const { getByText } = await renderDetails('pain-paracetamol', stores);
    await waitFor(() => expect(getByText('Paracetamol')).toBeOnTheScreen());

    await fireEvent.press(getByText('Add to cart'));

    expect(Alert.alert).toHaveBeenCalledWith(
      'Start a new pharmacy cart?',
      expect.any(String),
      expect.any(Array),
      expect.anything(),
    );
    expect(stores.cartStore.getState().items[0].product.id).toBe('other-item');

    const buttons = (Alert.alert as jest.Mock).mock.calls[0][2] as { text: string; onPress?: () => void }[];
    await act(async () => {
      buttons.find((button) => button.text === 'Start new cart')!.onPress!();
    });

    const items = stores.cartStore.getState().items;
    expect(items).toHaveLength(1);
    expect(items[0].product.id).toBe('pain-paracetamol');
  });
});
