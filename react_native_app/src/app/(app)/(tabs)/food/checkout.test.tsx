/**
 * Covers `FoodCheckoutScreen` (issue #387 / P6-06), porting the FOOD cases
 * of flutter_app/test/checkout_screens_test.dart.
 *
 * Ported:
 * - `food checkout` group: 'placing an order surfaces an error, resets the
 *   submit button, and keeps the cart when the order repository throws'
 *   (minus its activity assertion -- RN keeps no client-side activity
 *   record, see checkout.tsx's top comment), and 'asks only for an optional
 *   delivery note (no address, no payment picker) and sends the note with
 *   the order'.
 * - The `a double-tap on the submit button places only one order (#59)`
 *   group's `food` case, extended to also assert the RPC params carry the
 *   idempotency key and no client-computed prices.
 *
 * Skipped:
 * - `grocery checkout` group and the grocery/pharmacy double-tap cases --
 *   other verticals' checkout screens (separate issues).
 * - `confirmDemoOrder` group -- already ported in
 *   `src/platform/orders/confirm-order-flow.test.ts` (#379).
 * - Flutter's `setSurfaceSize` calls are layout-only scaffolding (making
 *   room so nothing overflows); RN has no equivalent of Flutter's overflow
 *   exceptions, so there is nothing to port.
 *
 * Extra RN-only cases: success clears the cart and opens order tracking; a
 * retry after a failure reuses the same idempotency key; a double tap
 * within the same frame (before the disabled button re-renders) is still
 * dropped; the missing-contact-details server message is surfaced; the
 * empty-cart browse action.
 *
 * Whether the order really lands in the database with server-computed
 * prices cannot be verified from here (no live database in tests); the RPC
 * param/response assertions stand in for that.
 *
 * Seams: `expo-router` and `@/platform/supabase/client` are mocked (the
 * latter with a `rpc` jest.fn); the real `useFoodCartStore` singleton is
 * used (reset in `afterEach`); pricing is seeded into the render's
 * `QueryClient` as in `cart.test.tsx`.
 */
import AsyncStorage from '@react-native-async-storage/async-storage';
import { PostgrestError } from '@supabase/supabase-js';
import { QueryClient } from '@tanstack/react-query';
import { act, fireEvent, waitFor } from '@testing-library/react-native';
import { router } from 'expo-router';
import { Alert } from 'react-native';

import { AppRoutes, trackOrderDetailsPath } from '@/platform/navigation/app-routes';
import { missingContactDetailsMessage } from '@/platform/orders/order-errors';
import type { ServicePricing } from '@/platform/pricing/service-pricing-repository';
import { useFoodCartStore, type CartItem } from '@/stores/food-cart-store';
import { createTestQueryClient, renderWithProviders } from '@/test-utils';

import FoodCheckoutScreen from './checkout';

jest.mock('expo-router', () => ({
  router: {
    push: jest.fn(),
    canGoBack: jest.fn(() => true),
    back: jest.fn(),
    replace: jest.fn(),
  },
}));

const mockRpc = jest.fn();
jest.mock('@/platform/supabase/client', () => ({
  supabase: { rpc: (...args: unknown[]) => mockRpc(...args) },
}));

// Wraps the real `CheckoutView` so a test can grab the `onSubmit` prop it was rendered with.
const mockCheckoutView = jest.fn();
jest.mock('@/components/checkout-view', () => {
  const actual = jest.requireActual('@/components/checkout-view');
  return {
    ...actual,
    CheckoutView: (props: { onSubmit: () => void }) => {
      mockCheckoutView(props);
      return actual.CheckoutView(props);
    },
  };
});

const burger: CartItem = {
  menuItemId: 'burger-1',
  restaurantId: 'restaurant-1',
  restaurantName: 'Test Kitchen',
  name: 'Classic Burger',
  unitPrice: 1000,
  imageUrl: '',
  quantity: 1,
};

const foodPricing: ServicePricing = { serviceId: 'food', deliveryFeeCents: 499, taxRate: 0.1 };

const placedRow = { order_id: 'order-123', subtotal: 1000, delivery_fee: 499, tax: 100, total: 1599 };

const initialCartState = useFoodCartStore.getState();
const renderedQueryClients: QueryClient[] = [];

/** A `place_food_order` call that never resolves, so a second tap happens while the first is in flight. */
function pendingRpc() {
  return new Promise(() => {});
}

async function renderScreen({ items = [burger] as CartItem[] } = {}) {
  useFoodCartStore.setState({ items, ownerId: 'user-1', isLoading: false });
  const queryClient = createTestQueryClient();
  queryClient.setQueryData(['service-pricing', 'food'], foodPricing);
  renderedQueryClients.push(queryClient);
  return renderWithProviders(<FoodCheckoutScreen />, { queryClient });
}

beforeEach(async () => {
  await AsyncStorage.clear();
  // `ErrorReporting`'s default reporter logs failed submissions via console.error.
  jest.spyOn(console, 'error').mockImplementation(() => {});
});

afterEach(() => {
  jest.restoreAllMocks();
  jest.clearAllMocks();
  mockRpc.mockReset();
  useFoodCartStore.setState(initialCartState, true);
  renderedQueryClients.splice(0).forEach((client) => client.clear());
});

describe('FoodCheckoutScreen', () => {
  it('surfaces an error, resets the submit button, and keeps the cart when placing the order fails', async () => {
    mockRpc.mockResolvedValue({ data: null, error: new Error('Simulated network failure while placing food order') });
    const { getByTestId, findByText, getByText, queryByText } = await renderScreen();

    await fireEvent.press(getByTestId('checkout-place-order'));

    expect(await findByText('The food order could not be saved. Please try again.')).toBeOnTheScreen();
    // The submit button resets back to its idle label instead of being stuck on "Placing order...".
    expect(getByText('Place order • $15.99')).toBeOnTheScreen();
    expect(queryByText('Placing order...')).toBeNull();
    expect(getByTestId('checkout-place-order')).toBeEnabled();

    // The cart must not be cleared on a failed order placement.
    expect(useFoodCartStore.getState().items).toHaveLength(1);
    expect(useFoodCartStore.getState().items[0].menuItemId).toBe(burger.menuItemId);
    expect(router.replace).not.toHaveBeenCalled();
  });

  it('asks only for an optional delivery note (no address, no payment picker) and sends the note with the order', async () => {
    mockRpc.mockImplementation(pendingRpc);
    const { container, getByTestId, getByText, queryByText } = await renderScreen();

    expect(container.queryAll((node) => node.type === 'TextInput')).toHaveLength(1);
    expect(getByText('Delivery note / landmark (optional)')).toBeOnTheScreen();
    expect(queryByText(/Street/)).toBeNull();
    expect(queryByText(/District/)).toBeNull();
    expect(queryByText('Payment method')).toBeNull();
    expect(getByText('Pay on delivery')).toBeOnTheScreen();
    expect(getByText('Classic Burger ×1')).toBeOnTheScreen();

    await fireEvent.changeText(getByTestId('checkout-delivery-note'), 'Blue gate');
    await fireEvent.press(getByTestId('checkout-place-order'));

    expect(mockRpc).toHaveBeenCalledTimes(1);
    expect(mockRpc.mock.calls[0][1].p_street).toBe('Blue gate');
  });

  it('a double tap on "Place order" places only one order, with an idempotency key and no client-computed prices', async () => {
    mockRpc.mockImplementation(pendingRpc);
    const { getByTestId, getByText } = await renderScreen({ items: [{ ...burger, quantity: 2 }] });

    await fireEvent.press(getByTestId('checkout-place-order'));
    expect(getByText('Placing order...')).toBeOnTheScreen();
    await fireEvent.press(getByTestId('checkout-place-order'));

    expect(mockRpc).toHaveBeenCalledTimes(1);
    const [name, params] = mockRpc.mock.calls[0];
    expect(name).toBe('place_food_order');
    expect(params).toEqual({
      p_restaurant_id: 'restaurant-1',
      p_recipient_name: '',
      p_phone: '',
      p_street: '',
      p_district: '',
      p_city: '',
      p_items: [{ menu_item_id: 'burger-1', quantity: 2 }],
      p_idempotency_key: expect.stringMatching(/^[0-9a-f]{32}$/),
    });
    // Ids and quantities only: nothing price-like is sent for the server to trust.
    expect(JSON.stringify(params)).not.toMatch(/price|subtotal|total|fee|tax/i);
  });

  it('drops a second tap in the same frame, before the disabled button has re-rendered', async () => {
    mockRpc.mockImplementation(pendingRpc);
    await renderScreen();

    // Call the screen's submit handler twice synchronously -- the second
    // call lands before React re-renders the button as disabled, so only
    // the in-flight ref guard can drop it.
    const { onSubmit } = mockCheckoutView.mock.calls.at(-1)![0];
    await act(async () => {
      onSubmit();
      onSubmit();
    });

    expect(mockRpc).toHaveBeenCalledTimes(1);
  });

  it('a retry after a failure reuses the same idempotency key', async () => {
    mockRpc
      .mockResolvedValueOnce({ data: null, error: new Error('lost response') })
      .mockImplementationOnce(pendingRpc);
    const { getByTestId, findByText } = await renderScreen();

    await fireEvent.press(getByTestId('checkout-place-order'));
    await findByText('The food order could not be saved. Please try again.');
    await fireEvent.press(getByTestId('checkout-place-order'));

    expect(mockRpc).toHaveBeenCalledTimes(2);
    expect(mockRpc.mock.calls[1][1].p_idempotency_key).toBe(mockRpc.mock.calls[0][1].p_idempotency_key);
  });

  it('on success clears the food cart and opens order tracking for the server-returned order id', async () => {
    const alertSpy = jest.spyOn(Alert, 'alert').mockImplementation(() => {});
    mockRpc.mockResolvedValue({ data: [placedRow], error: null });
    const { getByTestId } = await renderScreen();

    await fireEvent.press(getByTestId('checkout-place-order'));

    await waitFor(() =>
      expect(router.replace).toHaveBeenCalledWith(trackOrderDetailsPath({ serviceId: 'food', orderId: 'order-123' })),
    );
    expect(useFoodCartStore.getState().items).toHaveLength(0);
    expect(alertSpy).toHaveBeenCalledWith('Order placed', 'Your order was sent to the restaurant. Pay on delivery.');
  });

  it('shows the server message when the profile has no name/phone', async () => {
    mockRpc.mockResolvedValue({
      data: null,
      error: new PostgrestError({
        message: `${missingContactDetailsMessage}`,
        details: '',
        hint: '',
        code: 'P0001',
      }),
    });
    const { getByTestId, findByText } = await renderScreen();

    await fireEvent.press(getByTestId('checkout-place-order'));

    expect(await findByText(`${missingContactDetailsMessage}.`)).toBeOnTheScreen();
  });

  it('an empty cart shows the empty state with no place-order button, and browse goes to the home tab', async () => {
    const { getByText, queryByTestId } = await renderScreen({ items: [] });

    expect(getByText('Your cart is empty')).toBeOnTheScreen();
    expect(queryByTestId('checkout-place-order')).toBeNull();

    await fireEvent.press(getByText('Browse restaurants'));

    expect(router.replace).toHaveBeenCalledWith(AppRoutes.mainApp);
  });
});
