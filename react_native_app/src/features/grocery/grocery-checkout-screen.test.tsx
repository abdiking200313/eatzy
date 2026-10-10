/**
 * Covers `GroceryCheckoutScreen` (issue #392 / P7-04), porting the GROCERY
 * cases of flutter_app/test/checkout_screens_test.dart:
 *
 * - `grocery checkout` group: 'an incomplete grocery checkout flags only the
 *   slot and substitution sections, since there are no address fields to
 *   fill'.
 * - the `a double-tap on the submit button places only one order (#59)`
 *   group's `grocery` case (which also covers grocery_controller_test.dart's
 *   'confirmOrder ignores a second call while a submission is in flight').
 *
 * Skipped: the food/pharmacy cases (other issues) and the `confirmDemoOrder`
 * group (already ported in `confirm-order-flow.test.ts`, #379).
 *
 * Extra RN-only cases: a valid order is sent with the chosen slot,
 * preference, note and idempotency key, clears the cart and opens the
 * activity tab; an elapsed slot is rejected with Flutter's generic message
 * and keeps the cart; a retry reuses the same idempotency key; slots load
 * for the cart's store (and a load failure is shown); per-store-type titles.
 */
import { PostgrestError } from '@supabase/supabase-js';
import { QueryClient } from '@tanstack/react-query';
import { act, fireEvent, waitFor } from '@testing-library/react-native';
import { router } from 'expo-router';
import { Alert } from 'react-native';

import { AppRoutes } from '@/platform/navigation/app-routes';
import type { PlacedOrder } from '@/platform/orders/placed-order';
import type { ServicePricing } from '@/platform/pricing/service-pricing-repository';
import { groceryCartStores, type GroceryCartLine, type GroceryProduct, type GroceryStoreType } from '@/stores/grocery-cart-store';
import { createTestQueryClient, renderWithProviders } from '@/test-utils';

import type { GroceryDeliverySlot, GroceryOrderRequest } from './api/grocery-order-repository';
import { GroceryCheckoutScreen } from './grocery-checkout-screen';

jest.mock('expo-router', () => ({
  router: { push: jest.fn(), canGoBack: jest.fn(() => true), back: jest.fn(), replace: jest.fn() },
}));

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

const rice: GroceryProduct = {
  id: 'bakaal-rice',
  storeId: 'bakaal-fresh',
  name: 'Basmati rice',
  description: 'One 5 kg bag',
  unitPrice: 850,
  pricingUnit: 'each',
  stockState: 'inStock',
  availableQuantity: 24,
  icon: '🛒',
};
const bananas: GroceryProduct = { ...rice, id: 'bakaal-bananas', name: 'Bananas', unitPrice: 180, pricingUnit: 'kilogram' };

const slots: GroceryDeliverySlot[] = [
  { id: 'today-evening', label: 'Today', detail: '6:00 PM – 8:00 PM', storeId: 'bakaal-fresh' },
  { id: 'tomorrow-morning', label: 'Tomorrow', detail: '9:00 AM – 11:00 AM', storeId: 'bakaal-fresh' },
];

const pricing: ServicePricing = { serviceId: 'grocery', deliveryFeeCents: 250, taxRate: 0 };
const placed: PlacedOrder = { orderId: 'grocery-order-1', subtotal: 1120, deliveryFee: 250, tax: 0, total: 1370 };

const renderedQueryClients: QueryClient[] = [];

async function renderScreen({
  storeType = 'grocery' as GroceryStoreType,
  lines = [
    { product: rice, quantity: 1 },
    { product: bananas, quantity: 1.5 },
  ] as GroceryCartLine[],
  slotsLoader = jest.fn(async () => slots),
  placeOrder = jest.fn(async (_request: GroceryOrderRequest) => placed),
} = {}) {
  groceryCartStores[storeType].store.setState({ lines, ownerId: 'user-1', isLoading: false });
  const queryClient = createTestQueryClient();
  queryClient.setQueryData(['service-pricing', 'grocery'], pricing);
  renderedQueryClients.push(queryClient);
  const view = await renderWithProviders(
    <GroceryCheckoutScreen storeType={storeType} slotsLoader={slotsLoader} placeOrder={placeOrder} />,
    { queryClient },
  );
  return { ...view, slotsLoader, placeOrder };
}

beforeEach(() => {
  jest.spyOn(console, 'error').mockImplementation(() => {});
  jest.spyOn(Alert, 'alert').mockImplementation(() => {});
});

afterEach(() => {
  jest.restoreAllMocks();
  jest.clearAllMocks();
  for (const handle of Object.values(groceryCartStores)) {
    handle.store.setState({ lines: [], ownerId: null, isLoading: false });
  }
  renderedQueryClients.splice(0).forEach((client) => client.clear());
});

describe('GroceryCheckoutScreen', () => {
  it('flags only the slot and substitution sections on an incomplete checkout, since there are no address fields', async () => {
    const { getByTestId, findByText, getByText, queryByTestId, container, placeOrder } = await renderScreen();
    await findByText('6:00 PM – 8:00 PM');

    expect(container.queryAll((node) => node.type === 'TextInput')).toHaveLength(1);

    await fireEvent.press(getByTestId('checkout-place-order'));

    expect(getByText('Choose a delivery slot.')).toBeOnTheScreen();
    expect(getByText('Choose a substitution preference.')).toBeOnTheScreen();
    expect(queryByTestId('checkout-error')).toBeNull();
    expect(placeOrder).not.toHaveBeenCalled();
  });

  it('loads delivery slots for the cart store and lists every substitution option', async () => {
    const { findByText, getByText, slotsLoader } = await renderScreen();

    expect(await findByText('9:00 AM – 11:00 AM')).toBeOnTheScreen();
    expect(slotsLoader).toHaveBeenCalledWith('bakaal-fresh');
    expect(getByText('Delivery slot')).toBeOnTheScreen();
    expect(getByText('If an item becomes unavailable')).toBeOnTheScreen();
    expect(getByText('Choose the best match')).toBeOnTheScreen();
    expect(getByText('Contact me first')).toBeOnTheScreen();
    expect(getByText('No substitutions')).toBeOnTheScreen();
    expect(getByText('Basmati rice ×1')).toBeOnTheScreen();
    expect(getByText('Bananas ×1.5 kg')).toBeOnTheScreen();
    expect(getByText('Place order • $13.70')).toBeOnTheScreen();
  });

  it('shows an error when delivery slots fail to load', async () => {
    const { findByText } = await renderScreen({ slotsLoader: jest.fn(async () => Promise.reject(new Error('offline'))) });

    expect(await findByText('Delivery slots could not be loaded.')).toBeOnTheScreen();
  });

  it('places a valid order with the chosen slot, preference, note and key, clears the cart and opens activity', async () => {
    const { getByTestId, findByTestId, placeOrder } = await renderScreen();

    await fireEvent.changeText(getByTestId('checkout-delivery-note'), 'Blue gate');
    await fireEvent.press(await findByTestId('grocery-slot-tomorrow-morning'));
    await fireEvent.press(getByTestId('grocery-substitution-noSubstitutions'));
    await fireEvent.press(getByTestId('checkout-place-order'));

    await waitFor(() => expect(router.replace).toHaveBeenCalledWith(AppRoutes.activity));
    expect(placeOrder).toHaveBeenCalledTimes(1);
    expect(placeOrder).toHaveBeenCalledWith({
      storeId: 'bakaal-fresh',
      deliverySlotId: 'tomorrow-morning',
      delivery: { note: 'Blue gate' },
      substitutionPreference: 'noSubstitutions',
      items: [
        { productId: 'bakaal-rice', quantity: 1 },
        { productId: 'bakaal-bananas', quantity: 1.5 },
      ],
      idempotencyKey: expect.any(String),
    });
    expect(groceryCartStores.grocery.store.getState().lines).toEqual([]);
    expect(Alert.alert).toHaveBeenCalledWith('Order placed', expect.stringContaining('Reference: grocery-order-1'));
  });

  it('rejects a slot that has passed with the same generic message as Flutter, keeps the cart, and retries with the same key', async () => {
    const placeOrder = jest.fn(async (_request: GroceryOrderRequest): Promise<PlacedOrder> => {
      throw new PostgrestError({
        message: 'The selected delivery window has already passed. Please choose another delivery slot.',
        details: '',
        hint: '',
        code: 'P0001',
      });
    });
    const { getByTestId, findByTestId, findByText, queryByText } = await renderScreen({ placeOrder });

    await fireEvent.press(await findByTestId('grocery-slot-today-evening'));
    await fireEvent.press(getByTestId('grocery-substitution-contactMe'));
    await fireEvent.press(getByTestId('checkout-place-order'));

    expect(await findByText('The grocery order could not be saved. Please try again.')).toBeOnTheScreen();
    expect(queryByText(/delivery window has already passed/)).toBeNull();
    expect(groceryCartStores.grocery.store.getState().lines).toHaveLength(2);
    expect(router.replace).not.toHaveBeenCalled();
    expect(getByTestId('checkout-place-order')).toBeEnabled();

    await fireEvent.press(getByTestId('checkout-place-order'));
    await waitFor(() => expect(placeOrder).toHaveBeenCalledTimes(2));
    expect(placeOrder.mock.calls[1][0].idempotencyKey).toBe(placeOrder.mock.calls[0][0].idempotencyKey);
  });

  it('places only one order on a double tap (#59)', async () => {
    const placeOrder = jest.fn((_request: GroceryOrderRequest) => new Promise<PlacedOrder>(() => {}));
    const { getByTestId, findByTestId, getByText } = await renderScreen({ placeOrder });

    await fireEvent.press(await findByTestId('grocery-slot-today-evening'));
    await fireEvent.press(getByTestId('grocery-substitution-bestMatch'));

    await act(async () => {
      fireEvent.press(getByTestId('checkout-place-order'));
      fireEvent.press(getByTestId('checkout-place-order'));
    });
    expect(getByText('Placing order...')).toBeOnTheScreen();
    await fireEvent.press(getByTestId('checkout-place-order'));

    expect(placeOrder).toHaveBeenCalledTimes(1);
  });

  // Completes grocery_controller_test.dart's "confirmOrder ignores a second
  // call while a submission is in flight (issue #59)": the dropped call must
  // not disturb the first one, which still succeeds (issue #396 parity).
  it('a dropped second tap does not disturb the first submission, which still completes', async () => {
    let resolveOrder!: (order: PlacedOrder) => void;
    const placeOrder = jest.fn((_request: GroceryOrderRequest) => new Promise<PlacedOrder>((resolve) => (resolveOrder = resolve)));
    const { getByTestId, findByTestId, getByText } = await renderScreen({ placeOrder });

    await fireEvent.press(await findByTestId('grocery-slot-today-evening'));
    await fireEvent.press(getByTestId('grocery-substitution-bestMatch'));
    await fireEvent.press(getByTestId('checkout-place-order'));
    expect(getByText('Placing order...')).toBeOnTheScreen();
    await fireEvent.press(getByTestId('checkout-place-order'));
    expect(placeOrder).toHaveBeenCalledTimes(1);

    await act(async () => {
      resolveOrder(placed);
    });

    await waitFor(() => expect(router.replace).toHaveBeenCalledWith(AppRoutes.activity));
    expect(router.replace).toHaveBeenCalledTimes(1);
    expect(placeOrder).toHaveBeenCalledTimes(1);
    expect(groceryCartStores.grocery.store.getState().lines).toEqual([]);
    expect(Alert.alert).toHaveBeenCalledTimes(1);
  });

  it('titles each store type and offers to browse stores from an empty cart', async () => {
    const { getByText } = await renderScreen({ storeType: 'fresh_meat', lines: [] });

    expect(getByText('Fresh Meat checkout')).toBeOnTheScreen();
    expect(getByText('Your cart is empty')).toBeOnTheScreen();
    await fireEvent.press(getByText('Browse stores'));
    expect(router.replace).toHaveBeenCalledWith(AppRoutes.freshMeat);
  });
});
