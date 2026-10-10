/**
 * Covers `PharmacyCartScreen` (issue #395 / P7-07), porting the pharmacy
 * cases of `flutter_app/test/cart_screens_test.dart`:
 *
 * - `pharmacy cart` group: 'renders items, the OTC reminder and totals;
 *   increase/decrease updates totals; Clear empties the cart',
 *   'decrementing the only unit of an item removes it and shows the empty
 *   state', and 'an item already at its stock ceiling disables the increase
 *   button instead of over-adding it'.
 * - `shared cart behavior` group's pharmacy case: an empty cart has no
 *   checkout button and "Browse pharmacy" returns to the catalog; a filled
 *   cart continues to checkout.
 *
 * `flutter_app/test/pharmacy_screens_test.dart` (named by the issue) has no
 * cart/checkout/details cases -- those live in the files above.
 */
import { QueryClient } from '@tanstack/react-query';
import { act, fireEvent } from '@testing-library/react-native';
import { router } from 'expo-router';
import { Alert } from 'react-native';

import { AppRoutes } from '@/platform/navigation/app-routes';
import type { ServicePricing } from '@/platform/pricing/service-pricing-repository';
import { createPharmacyCartStore, type PharmacyProduct } from '@/stores/pharmacy-cart-store';
import { SessionResetRegistry } from '@/stores/session-reset-registry';
import { createTestQueryClient, renderWithProviders } from '@/test-utils';
import { MemoryCartStorage } from '@/test-utils/memory-cart-storage';

import { SEEDED_PHARMACY_PRODUCTS } from './api/pharmacy-repository';
import { PharmacyCartScreen } from './pharmacy-cart-screen';

jest.mock('expo-router', () => ({
  router: { push: jest.fn(), canGoBack: jest.fn(() => true), back: jest.fn(), replace: jest.fn() },
}));

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

const seeded = (id: string): PharmacyProduct => SEEDED_PHARMACY_PRODUCTS.find((product) => product.id === id)!;

const pricing: ServicePricing = { serviceId: 'pharmacy', deliveryFeeCents: 250, taxRate: 0 };
const renderedQueryClients: QueryClient[] = [];

async function renderScreen(fill: (cart: ReturnType<typeof buildCartStore>) => void = () => {}) {
  const cartStore = buildCartStore();
  fill(cartStore);
  const queryClient = createTestQueryClient();
  queryClient.setQueryData(['service-pricing', 'pharmacy'], pricing);
  renderedQueryClients.push(queryClient);
  const view = await renderWithProviders(<PharmacyCartScreen cartStore={cartStore} />, { queryClient });
  return { ...view, cartStore };
}

function buildCartStore() {
  return createPharmacyCartStore({ storage: new MemoryCartStorage(), registry: new SessionResetRegistry() }).store;
}

beforeEach(() => {
  jest.spyOn(Alert, 'alert').mockImplementation(() => {});
});

afterEach(() => {
  jest.restoreAllMocks();
  jest.clearAllMocks();
  renderedQueryClients.splice(0).forEach((client) => client.clear());
});

describe('PharmacyCartScreen', () => {
  it('renders items, the OTC reminder and totals; increase/decrease updates totals; Clear empties the cart', async () => {
    const { getByText, getByTestId, queryByText, cartStore } = await renderScreen((cart) => {
      cart.getState().addProduct(seeded('pain-paracetamol'));
      cart.getState().addProduct(seeded('first-aid-bandages'));
    });

    expect(getByText(/separate from food and grocery/)).toBeOnTheScreen();
    expect(getByText('Paracetamol')).toBeOnTheScreen();
    expect(getByText('Adhesive Bandages')).toBeOnTheScreen();
    expect(getByText('$2.75')).toBeOnTheScreen();

    const paracetamolQuantity = () => cartStore.getState().items.find((item) => item.product.id === 'pain-paracetamol')!.quantity;

    await fireEvent.press(getByTestId('increase-cart-item-pain-paracetamol'));
    expect(paracetamolQuantity()).toBe(2);
    expect(getByText('$5.50')).toBeOnTheScreen();
    expect(getByText('$8.75')).toBeOnTheScreen();

    await fireEvent.press(getByTestId('decrease-cart-item-pain-paracetamol'));
    expect(paracetamolQuantity()).toBe(1);

    expect(getByText('Subtotal')).toBeOnTheScreen();
    expect(getByText('$6.00')).toBeOnTheScreen();
    expect(getByText('Delivery fee')).toBeOnTheScreen();
    expect(getByText('$2.50')).toBeOnTheScreen();
    expect(getByText('Total')).toBeOnTheScreen();
    expect(getByText('$8.50')).toBeOnTheScreen();

    await fireEvent.press(getByText('Clear'));
    const buttons = (Alert.alert as jest.Mock).mock.calls[0][2] as { text: string; onPress?: () => void }[];
    await act(async () => {
      buttons.find((button) => button.text === 'Clear cart')!.onPress!();
    });

    expect(cartStore.getState().items).toEqual([]);
    expect(getByText('Your pharmacy cart is empty')).toBeOnTheScreen();
    expect(queryByText('Clear')).toBeNull();
  });

  it('decrementing the only unit of an item removes it and shows the empty state', async () => {
    const { getByTestId, findByText, queryByText, cartStore } = await renderScreen((cart) => {
      cart.getState().addProduct(seeded('pain-paracetamol'));
    });

    await fireEvent.press(getByTestId('decrease-cart-item-pain-paracetamol'));

    expect(cartStore.getState().items).toEqual([]);
    expect(await findByText('Your pharmacy cart is empty')).toBeOnTheScreen();
    expect(queryByText('Clear')).toBeNull();
  });

  it('an item already at its stock ceiling disables the increase button instead of over-adding it', async () => {
    const { getByTestId, cartStore } = await renderScreen((cart) => {
      // `cold-cough-syrup` is seeded with `stockQuantity: 4`.
      cart.getState().addProduct(seeded('cold-cough-syrup'), { quantity: 4 });
    });

    expect(getByTestId('increase-cart-item-cold-cough-syrup')).toBeDisabled();
    await fireEvent.press(getByTestId('increase-cart-item-cold-cough-syrup'));
    expect(cartStore.getState().items[0].quantity).toBe(4);
  });

  it('an empty cart has no checkout button, and "Browse pharmacy" navigates back to the catalog', async () => {
    const { getByText, queryByTestId } = await renderScreen();

    expect(getByText('Your pharmacy cart is empty')).toBeOnTheScreen();
    expect(queryByTestId('cart-checkout')).toBeNull();
    await fireEvent.press(getByText('Browse pharmacy'));
    expect(router.replace).toHaveBeenCalledWith(AppRoutes.pharmacy);
  });

  it('a filled cart continues to checkout', async () => {
    const { getByTestId } = await renderScreen((cart) => {
      cart.getState().addProduct(seeded('pain-paracetamol'));
    });

    await fireEvent.press(getByTestId('cart-checkout'));
    expect(router.push).toHaveBeenCalledWith(AppRoutes.pharmacyCheckout);
  });
});
