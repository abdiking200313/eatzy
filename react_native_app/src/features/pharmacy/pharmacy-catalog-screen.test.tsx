/**
 * Ports the "catalog" group of `flutter_app/test/pharmacy_screens_test.dart`
 * (issue #394 / P7-06). The Dart "tapping a product opens its details page,
 * which adds the picked quantity" case is ported only up to the navigation
 * itself -- `PharmacyProductDetailsScreen` is a later issue's port, so this
 * asserts the catalog pushes the right product-details route.
 */
import { act, fireEvent, waitFor } from '@testing-library/react-native';
import { router } from 'expo-router';
import { Alert } from 'react-native';

import { createPharmacyCartStore, type PharmacyProduct } from '@/stores/pharmacy-cart-store';
import { SessionResetRegistry } from '@/stores/session-reset-registry';
import { renderWithProviders } from '@/test-utils';
import { MemoryCartStorage } from '@/test-utils/memory-cart-storage';

import {
  createInMemoryPharmacyRepository,
  SEEDED_PHARMACY_STORE_ID,
  type PharmacyRepository,
} from './api/pharmacy-repository';
import { PharmacyCatalogScreen } from './pharmacy-catalog-screen';
import { createPharmacyCatalogStore } from './pharmacy-catalog-store';

jest.mock('expo-router', () => ({
  router: { push: jest.fn(), back: jest.fn(), replace: jest.fn(), canGoBack: jest.fn(() => true) },
}));

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

function product(id: string, storeId: string, name: string, description: string): PharmacyProduct {
  return { id, storeId, name, description, category: 'General', unitPrice: 3, stockQuantity: 10, saleType: 'overTheCounter' };
}

/** Mirrors the Dart test's `_MultiStorePharmacyRepository`. */
const multiStoreRepository = () =>
  createInMemoryPharmacyRepository([
    product('store-a-vitamin', 'store-a', 'Vitamin A', 'Store A vitamin.'),
    product('store-a-bandages', 'store-a', 'Bandages A', 'Store A first aid.'),
    product('store-b-item', 'store-b', 'Store B item', 'Store B essential.'),
  ]);

/** Mirrors `_CountingPharmacyRepository` over the seeded catalog. */
function countingRepository() {
  const inner = createInMemoryPharmacyRepository();
  const counter = { fetchCount: 0 };
  const repository: PharmacyRepository = {
    fetchProducts: (options) => {
      counter.fetchCount += 1;
      return inner.fetchProducts(options);
    },
  };
  return { repository, counter };
}

function buildCartStore() {
  return createPharmacyCartStore({ storage: new MemoryCartStorage(), registry: new SessionResetRegistry() }).store;
}

beforeEach(() => {
  (router.push as jest.Mock).mockClear();
});

afterEach(() => {
  jest.restoreAllMocks();
});

describe('PharmacyCatalogScreen', () => {
  it('clearly explains the OTC-only scope and shows stock state', async () => {
    const { getByText, getAllByText } = await renderWithProviders(
      <PharmacyCatalogScreen
        storeId={SEEDED_PHARMACY_STORE_ID}
        storeName="Hodan Pharmacy"
        catalogStore={createPharmacyCatalogStore({ repository: createInMemoryPharmacyRepository() })}
        cartStore={buildCartStore()}
      />,
    );

    await waitFor(() => expect(getByText('Paracetamol')).toBeOnTheScreen());
    expect(getAllByText('Hodan Pharmacy').length).toBeGreaterThan(0);
    expect(getByText('Over-the-counter (OTC) only')).toBeOnTheScreen();
    expect(getByText(/does not accept prescriptions/)).toBeOnTheScreen();
    expect(getByText('Out of stock')).toBeOnTheScreen();
    expect(getByText('Only 4 left')).toBeOnTheScreen();
    expect(getByText('$2.75')).toBeOnTheScreen();
  });

  it('tapping a product opens its details route', async () => {
    const { getByText } = await renderWithProviders(
      <PharmacyCatalogScreen
        storeId={SEEDED_PHARMACY_STORE_ID}
        catalogStore={createPharmacyCatalogStore({ repository: createInMemoryPharmacyRepository() })}
        cartStore={buildCartStore()}
      />,
    );
    await waitFor(() => expect(getByText('Paracetamol')).toBeOnTheScreen());

    await fireEvent.press(getByText('Paracetamol'));

    expect(router.push).toHaveBeenCalledWith('/pharmacy/stores/legacy-pharmacy/product/pain-paracetamol');
  });

  it('pulling to refresh reloads the pharmacy catalog', async () => {
    const { repository, counter } = countingRepository();
    const { getByText, getByTestId } = await renderWithProviders(
      <PharmacyCatalogScreen
        storeId={SEEDED_PHARMACY_STORE_ID}
        catalogStore={createPharmacyCatalogStore({ repository })}
        cartStore={buildCartStore()}
      />,
    );
    await waitFor(() => expect(getByText('Paracetamol')).toBeOnTheScreen());
    expect(counter.fetchCount).toBe(1);

    await act(async () => {
      await getByTestId('pharmacy-catalog-list').props.refreshControl.props.onRefresh();
    });

    expect(counter.fetchCount).toBe(2);
  });

  it("typing a search term narrows this pharmacy's catalog", async () => {
    const { getByText, queryByText, getByPlaceholderText } = await renderWithProviders(
      <PharmacyCatalogScreen
        storeId="store-a"
        catalogStore={createPharmacyCatalogStore({ repository: multiStoreRepository() })}
        cartStore={buildCartStore()}
        debounceMs={10}
      />,
    );
    await waitFor(() => expect(getByText('Vitamin A')).toBeOnTheScreen());
    expect(getByText('Bandages A')).toBeOnTheScreen();

    await fireEvent.changeText(getByPlaceholderText('Search this pharmacy...'), 'Vitamin');

    await waitFor(() => expect(queryByText('Bandages A')).toBeNull());
    expect(getByText('Vitamin A')).toBeOnTheScreen();

    await fireEvent.changeText(getByPlaceholderText('Search this pharmacy...'), 'zzz');
    await waitFor(() => expect(getByText('No products match "zzz" at this pharmacy.')).toBeOnTheScreen());
  });

  it('adding a product from a different pharmacy prompts to replace the cart', async () => {
    const catalogStore = createPharmacyCatalogStore({ repository: multiStoreRepository() });
    const cartStore = buildCartStore();
    await catalogStore.getState().loadProducts({ storeId: 'store-a' });
    cartStore.getState().addProduct(catalogStore.getState().products[0]);
    expect(cartStore.getState().items[0].product.storeId).toBe('store-a');
    const alertSpy = jest.spyOn(Alert, 'alert').mockImplementation(() => {});

    const { getByText, getByLabelText, queryByText } = await renderWithProviders(
      <PharmacyCatalogScreen storeId="store-b" storeName="Store B" catalogStore={catalogStore} cartStore={cartStore} />,
    );
    // The previous pharmacy's products never render on this pharmacy's screen.
    expect(queryByText('Vitamin A')).toBeNull();
    await waitFor(() => expect(getByText('Store B item')).toBeOnTheScreen());

    await fireEvent.press(getByLabelText('Add Store B item'));

    expect(alertSpy).toHaveBeenCalledTimes(1);
    const [title, , buttons] = alertSpy.mock.calls[0];
    expect(title).toBe('Start a new pharmacy cart?');
    expect(buttons?.map((button) => button.text)).toEqual(['Keep cart', 'Start new cart']);
    expect(cartStore.getState().items[0].product.storeId).toBe('store-a');

    await act(async () => {
      buttons?.[1].onPress?.();
    });

    expect(cartStore.getState().items.map((item) => item.product.id)).toEqual(['store-b-item']);
    expect(getByText('Store B item added to pharmacy cart.')).toBeOnTheScreen();
  });

  it('an out-of-stock product cannot be added', async () => {
    const cartStore = buildCartStore();
    const { getByText, getByLabelText } = await renderWithProviders(
      <PharmacyCatalogScreen
        storeId={SEEDED_PHARMACY_STORE_ID}
        catalogStore={createPharmacyCatalogStore({ repository: createInMemoryPharmacyRepository() })}
        cartStore={cartStore}
      />,
    );
    await waitFor(() => expect(getByText('Allergy Relief')).toBeOnTheScreen());

    expect(getByLabelText('Out of stock')).toBeDisabled();
    await fireEvent.press(getByLabelText('Add Paracetamol'));
    expect(getByText('Paracetamol added to pharmacy cart.')).toBeOnTheScreen();
    expect(cartStore.getState().items).toHaveLength(1);
  });

  it('shows the load error with a working retry when the first load fails', async () => {
    let fail = true;
    const inner = createInMemoryPharmacyRepository();
    const catalogStore = createPharmacyCatalogStore({
      repository: { fetchProducts: (options) => (fail ? Promise.reject(new Error('offline')) : inner.fetchProducts(options)) },
    });
    const { getByText } = await renderWithProviders(
      <PharmacyCatalogScreen storeId={SEEDED_PHARMACY_STORE_ID} catalogStore={catalogStore} cartStore={buildCartStore()} />,
    );

    await waitFor(() => expect(getByText('The pharmacy catalog could not be loaded.')).toBeOnTheScreen());
    fail = false;
    await fireEvent.press(getByText('Try again'));

    await waitFor(() => expect(getByText('Paracetamol')).toBeOnTheScreen());
  });

  it('an empty pharmacy says it has no OTC products yet', async () => {
    const { getByText } = await renderWithProviders(
      <PharmacyCatalogScreen
        storeId="empty-store"
        catalogStore={createPharmacyCatalogStore({ repository: createInMemoryPharmacyRepository() })}
        cartStore={buildCartStore()}
      />,
    );

    await waitFor(() => expect(getByText('This pharmacy has no OTC products yet.')).toBeOnTheScreen());
  });
});
