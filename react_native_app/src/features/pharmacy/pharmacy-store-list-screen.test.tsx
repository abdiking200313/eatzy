/**
 * Ports the "store list" group of `flutter_app/test/pharmacy_screens_test.dart`
 * (issue #394 / P7-06). The Dart "overflow-free on a narrow, large-text
 * screen" assertion has no Jest equivalent (no layout engine) -- only its
 * "renders every pharmacy" half is ported. Debounce timing uses real timers
 * plus short real waits, same reasoning as `food/index.test.tsx`.
 */
import { act, fireEvent, waitFor } from '@testing-library/react-native';
import { router } from 'expo-router';

import { createPharmacyCartStore } from '@/stores/pharmacy-cart-store';
import { SessionResetRegistry } from '@/stores/session-reset-registry';
import { renderWithProviders } from '@/test-utils';
import { MemoryCartStorage } from '@/test-utils/memory-cart-storage';

import type { PharmacyStore } from './api/pharmacy-models';
import { PHARMACY_SEARCH_DEBOUNCE_MS, PharmacyStoreListScreen } from './pharmacy-store-list-screen';

jest.mock('expo-router', () => ({
  router: { push: jest.fn() },
}));

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

const stores: PharmacyStore[] = [
  { id: 'legacy-pharmacy', name: 'Legacy Pharmacy', address: 'Mogadishu, Somalia', imageUrl: null },
  { id: 'hodan-pharmacy', name: 'Hodan Pharmacy', address: 'Hodan, Mogadishu', imageUrl: null },
];

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function buildCartStore() {
  return createPharmacyCartStore({ storage: new MemoryCartStorage(), registry: new SessionResetRegistry() }).store;
}

beforeEach(() => {
  (router.push as jest.Mock).mockClear();
});

describe('PharmacyStoreListScreen', () => {
  it('renders every pharmacy with its address', async () => {
    const { getByText } = await renderWithProviders(
      <PharmacyStoreListScreen storeLoader={async () => stores} cartStore={buildCartStore()} />,
    );

    await waitFor(() => expect(getByText('Legacy Pharmacy')).toBeOnTheScreen());
    expect(getByText('Hodan Pharmacy')).toBeOnTheScreen();
    expect(getByText('Mogadishu, Somalia')).toBeOnTheScreen();
    expect(getByText('Pharmacies near you')).toBeOnTheScreen();
  });

  it('typing a search term debounces before filtering, and clearing restores the full list', async () => {
    const queryCalls: string[] = [];
    const { getByText, queryByText, getByPlaceholderText, getByLabelText } = await renderWithProviders(
      <PharmacyStoreListScreen
        storeLoader={async () => stores}
        cartStore={buildCartStore()}
        storeQuery={async (searchQuery) => {
          queryCalls.push(searchQuery);
          return [stores[1]];
        }}
      />,
    );
    await waitFor(() => expect(getByText('Legacy Pharmacy')).toBeOnTheScreen());

    await fireEvent.changeText(getByPlaceholderText('Search pharmacies...'), 'hodan');
    // Still within the debounce window -- no query fired yet.
    await act(() => sleep(100));
    expect(queryCalls).toEqual([]);

    await act(() => sleep(PHARMACY_SEARCH_DEBOUNCE_MS));
    await waitFor(() => expect(queryByText('Legacy Pharmacy')).toBeNull());
    expect(queryCalls).toEqual(['hodan']);
    expect(getByText('Hodan Pharmacy')).toBeOnTheScreen();

    await fireEvent.press(getByLabelText('Clear'));
    await waitFor(() => expect(getByText('Legacy Pharmacy')).toBeOnTheScreen());
  });

  it('an empty search result shows a reachable, honest empty state', async () => {
    const { getByText, getByPlaceholderText } = await renderWithProviders(
      <PharmacyStoreListScreen storeLoader={async () => stores} cartStore={buildCartStore()} storeQuery={async () => []} debounceMs={10} />,
    );
    await waitFor(() => expect(getByText('Legacy Pharmacy')).toBeOnTheScreen());

    await fireEvent.changeText(getByPlaceholderText('Search pharmacies...'), 'nowhere');

    await waitFor(() => expect(getByText('No pharmacies match "nowhere".')).toBeOnTheScreen());
  });

  it('tapping a pharmacy navigates to its scoped catalog route with the name (and photo) attached', async () => {
    const withPhoto: PharmacyStore = { ...stores[1], imageUrl: 'https://cdn.example/hodan photo.jpg' };
    const { getByText } = await renderWithProviders(
      <PharmacyStoreListScreen storeLoader={async () => [stores[0], withPhoto]} cartStore={buildCartStore()} />,
    );
    await waitFor(() => expect(getByText('Hodan Pharmacy')).toBeOnTheScreen());

    await fireEvent.press(getByText('Legacy Pharmacy'));
    expect(router.push).toHaveBeenLastCalledWith('/pharmacy/stores/legacy-pharmacy?name=Legacy%20Pharmacy');

    await fireEvent.press(getByText('Hodan Pharmacy'));
    expect(router.push).toHaveBeenLastCalledWith(
      '/pharmacy/stores/hodan-pharmacy?name=Hodan%20Pharmacy&photoUrl=https%3A%2F%2Fcdn.example%2Fhodan%20photo.jpg',
    );
  });

  it('shows an error with a working retry when the list fails to load, and an empty state for no pharmacies', async () => {
    let fail = true;
    const { getByText } = await renderWithProviders(
      <PharmacyStoreListScreen
        storeLoader={async () => {
          if (fail) throw new Error('offline');
          return [];
        }}
        cartStore={buildCartStore()}
      />,
    );

    await waitFor(() => expect(getByText('Pharmacies could not be loaded.')).toBeOnTheScreen());
    fail = false;
    await fireEvent.press(getByText('Try again'));

    await waitFor(() => expect(getByText('No pharmacies found.')).toBeOnTheScreen());
  });

  it('the cart badge reflects the pharmacy cart and opens the pharmacy cart', async () => {
    const cartStore = buildCartStore();
    cartStore.getState().addProduct(
      {
        id: 'p',
        storeId: 'legacy-pharmacy',
        name: 'Paracetamol',
        description: '',
        category: 'Pain relief',
        unitPrice: 275,
        stockQuantity: 5,
        saleType: 'overTheCounter',
      },
      { quantity: 2 },
    );
    const { getByLabelText, getByText } = await renderWithProviders(
      <PharmacyStoreListScreen storeLoader={async () => stores} cartStore={cartStore} />,
    );
    await waitFor(() => expect(getByText('Legacy Pharmacy')).toBeOnTheScreen());

    await fireEvent.press(getByLabelText('Pharmacy cart (2)'));
    expect(router.push).toHaveBeenLastCalledWith('/pharmacy/cart');
  });
});
