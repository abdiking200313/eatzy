/**
 * Covers `PharmacyCheckoutScreen` (issue #395 / P7-07), porting the
 * PHARMACY cases of flutter_app/test/checkout_screens_test.dart and
 * cart_screens_test.dart:
 *
 * - the `a double-tap on the submit button places only one order (#59)`
 *   group's `pharmacy` case (which also covers pharmacy_controller_test.dart's
 *   'placeDemoOrder ignores a second call while a submission is in flight').
 * - cart_screens_test.dart's `shared cart behavior` pharmacy case for the
 *   checkout half: an empty checkout offers "Browse OTC products".
 *
 * Extra RN-only cases: a valid order is sent with the note and idempotency
 * key, clears the cart and opens the activity tab; a failed order shows
 * Flutter's generic message, keeps the cart, and a retry reuses the same
 * idempotency key; there is no address field.
 */
import { QueryClient } from '@tanstack/react-query';
import { act, fireEvent, waitFor } from '@testing-library/react-native';
import { router } from 'expo-router';
import { Alert } from 'react-native';

import { AppRoutes } from '@/platform/navigation/app-routes';
import type { PlacedOrder } from '@/platform/orders/placed-order';
import type { ServicePricing } from '@/platform/pricing/service-pricing-repository';
import { createPharmacyCartStore, type PharmacyProduct } from '@/stores/pharmacy-cart-store';
import { SessionResetRegistry } from '@/stores/session-reset-registry';
import { createTestQueryClient, renderWithProviders } from '@/test-utils';
import { MemoryCartStorage } from '@/test-utils/memory-cart-storage';

import type { PharmacyOrderRequest } from './api/pharmacy-order-repository';
import { SEEDED_PHARMACY_PRODUCTS } from './api/pharmacy-repository';
import { PharmacyCheckoutScreen } from './pharmacy-checkout-screen';

jest.mock('expo-router', () => ({
  router: { push: jest.fn(), canGoBack: jest.fn(() => true), back: jest.fn(), replace: jest.fn() },
}));

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

const seeded = (id: string): PharmacyProduct => SEEDED_PHARMACY_PRODUCTS.find((product) => product.id === id)!;

const pricing: ServicePricing = { serviceId: 'pharmacy', deliveryFeeCents: 250, taxRate: 0 };
const placed: PlacedOrder = { orderId: 'pharmacy-order-1', subtotal: 825, deliveryFee: 250, tax: 0, total: 1075 };
const renderedQueryClients: QueryClient[] = [];

async function renderScreen({
  fill = true,
  placeOrder = jest.fn(async (_request: PharmacyOrderRequest) => placed),
} = {}) {
  const cartStore = createPharmacyCartStore({ storage: new MemoryCartStorage(), registry: new SessionResetRegistry() }).store;
  if (fill) {
    cartStore.getState().addProduct(seeded('pain-paracetamol'), { quantity: 3 });
  }
  const queryClient = createTestQueryClient();
  queryClient.setQueryData(['service-pricing', 'pharmacy'], pricing);
  renderedQueryClients.push(queryClient);
  const view = await renderWithProviders(<PharmacyCheckoutScreen cartStore={cartStore} placeOrder={placeOrder} />, { queryClient });
  return { ...view, cartStore, placeOrder };
}

beforeEach(() => {
  jest.spyOn(console, 'error').mockImplementation(() => {});
  jest.spyOn(Alert, 'alert').mockImplementation(() => {});
});

afterEach(() => {
  jest.restoreAllMocks();
  jest.clearAllMocks();
  renderedQueryClients.splice(0).forEach((client) => client.clear());
});

describe('PharmacyCheckoutScreen', () => {
  it('shows the order summary with only a delivery note -- no address fields', async () => {
    const { getByText, container } = await renderScreen();

    expect(getByText('Checkout')).toBeOnTheScreen();
    expect(container.queryAll((node) => node.type === 'TextInput')).toHaveLength(1);
    expect(getByText('Paracetamol ×3')).toBeOnTheScreen();
    // 3 × $2.75 = $8.25, plus a $2.50 delivery fee.
    expect(getByText('Place order • $10.75')).toBeOnTheScreen();
  });

  it('places the order with the note and key, clears the cart and opens activity', async () => {
    const { getByTestId, cartStore, placeOrder } = await renderScreen();

    await fireEvent.changeText(getByTestId('checkout-delivery-note'), 'Taleex Road, blue gate');
    await fireEvent.press(getByTestId('checkout-place-order'));

    await waitFor(() => expect(router.replace).toHaveBeenCalledWith(AppRoutes.activity));
    expect(placeOrder).toHaveBeenCalledTimes(1);
    expect(placeOrder).toHaveBeenCalledWith({
      delivery: { note: 'Taleex Road, blue gate' },
      items: [{ productId: 'pain-paracetamol', quantity: 3 }],
      idempotencyKey: expect.any(String),
    });
    expect(cartStore.getState().items).toEqual([]);
    expect(Alert.alert).toHaveBeenCalledWith('Order placed', expect.stringContaining('Pay on delivery'));
    expect(Alert.alert).toHaveBeenCalledWith('Order placed', expect.stringContaining('Reference: pharmacy-order-1'));
  });

  it('shows the generic error on failure, keeps the cart, and retries with the same key', async () => {
    const placeOrder = jest.fn(async (_request: PharmacyOrderRequest): Promise<PlacedOrder> => {
      throw new Error('network down');
    });
    const { getByTestId, findByText, cartStore } = await renderScreen({ placeOrder });

    await fireEvent.press(getByTestId('checkout-place-order'));

    expect(await findByText('The pharmacy order could not be saved. Please try again.')).toBeOnTheScreen();
    expect(cartStore.getState().items).toHaveLength(1);
    expect(router.replace).not.toHaveBeenCalled();
    expect(getByTestId('checkout-place-order')).toBeEnabled();

    await fireEvent.press(getByTestId('checkout-place-order'));
    await waitFor(() => expect(placeOrder).toHaveBeenCalledTimes(2));
    expect(placeOrder.mock.calls[1][0].idempotencyKey).toBe(placeOrder.mock.calls[0][0].idempotencyKey);
  });

  it('places only one order on a double tap (#59)', async () => {
    const placeOrder = jest.fn((_request: PharmacyOrderRequest) => new Promise<PlacedOrder>(() => {}));
    const { getByTestId, getByText } = await renderScreen({ placeOrder });

    await act(async () => {
      fireEvent.press(getByTestId('checkout-place-order'));
      fireEvent.press(getByTestId('checkout-place-order'));
    });
    expect(getByText('Placing order...')).toBeOnTheScreen();
    await fireEvent.press(getByTestId('checkout-place-order'));

    expect(placeOrder).toHaveBeenCalledTimes(1);
  });

  it('offers to browse OTC products from an empty cart', async () => {
    const { getByText, queryByTestId } = await renderScreen({ fill: false });

    expect(getByText('Your pharmacy cart is empty')).toBeOnTheScreen();
    expect(queryByTestId('checkout-place-order')).toBeNull();
    await fireEvent.press(getByText('Browse OTC products'));
    expect(router.replace).toHaveBeenCalledWith(AppRoutes.pharmacy);
  });
});
