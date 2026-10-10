/**
 * Covers `FoodCartScreen` (issue #386), porting the FOOD cases of
 * flutter_app/test/cart_screens_test.dart.
 *
 * Ported:
 * - 'cart screen updates quantities, totals, and removes items'.
 * - The `shared cart behavior` group's two cases (empty cart has no
 *   checkout button + browse navigates to the catalog; continue navigates
 *   to checkout). The Dart group only tables grocery/pharmacy, but the food
 *   screen has the same contract, so they are ported here for food.
 *
 * Skipped:
 * - 'checkout places an order that is paid on delivery' -- exercises the
 *   food *checkout* screen (`CheckoutScreen`), which is a separate issue,
 *   not this cart screen.
 * - All grocery/pharmacy groups (other verticals' cart screens).
 * - No Flutter layout-overflow (`tester.takeException()`) assertion exists
 *   in the food cases; the grocery/pharmacy ones are not portable anyway
 *   since RN has no equivalent of Flutter's overflow exceptions.
 *
 * Extra RN-only cases cover the quantity bounds (decrease disabled at 1,
 * increase disabled at `FOOD_CART_MAXIMUM_QUANTITY`), the confirmed Clear
 * action, and the "Calculated at checkout" pending-pricing state.
 *
 * Seams: `expo-router` and `@/platform/supabase/client` are mocked; the
 * real `useFoodCartStore` singleton is used (reset in `afterEach`); pricing
 * is seeded into the render's `QueryClient` under `useServicePricing`'s own
 * query key, standing in for Dart's `FakeServicePricingRepository.food()`
 * (499 cents delivery, 10% tax).
 */
import AsyncStorage from '@react-native-async-storage/async-storage';
import { QueryClient } from '@tanstack/react-query';
import { act, fireEvent, waitFor } from '@testing-library/react-native';
import { router } from 'expo-router';
import { Alert, type AlertButton } from 'react-native';

import { AppRoutes } from '@/platform/navigation/app-routes';
import type { ServicePricing } from '@/platform/pricing/service-pricing-repository';
import { FOOD_CART_MAXIMUM_QUANTITY, useFoodCartStore, type CartItem } from '@/stores/food-cart-store';
import { createTestQueryClient, renderWithProviders } from '@/test-utils';

import FoodCartScreen from './cart';

jest.mock('expo-router', () => ({
  router: {
    push: jest.fn(),
    canGoBack: jest.fn(() => true),
    back: jest.fn(),
    replace: jest.fn(),
  },
}));

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

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

const initialCartState = useFoodCartStore.getState();
const renderedQueryClients: QueryClient[] = [];

async function renderScreen({ items = [] as CartItem[], pricing = foodPricing as ServicePricing | null } = {}) {
  useFoodCartStore.setState({ items, ownerId: 'user-1', isLoading: false });
  const queryClient = createTestQueryClient();
  if (pricing) {
    queryClient.setQueryData(['service-pricing', 'food'], pricing);
  }
  renderedQueryClients.push(queryClient);
  return renderWithProviders(<FoodCartScreen />, { queryClient });
}

beforeEach(async () => {
  await AsyncStorage.clear();
});

afterEach(() => {
  jest.restoreAllMocks();
  jest.clearAllMocks();
  useFoodCartStore.setState(initialCartState, true);
  renderedQueryClients.splice(0).forEach((client) => client.clear());
});

describe('FoodCartScreen', () => {
  it('updates quantities, totals, and removes items', async () => {
    const { getByText, getByTestId } = await renderScreen({ items: [burger] });

    expect(getByText('Test Kitchen')).toBeOnTheScreen();
    expect(getByText('Classic Burger')).toBeOnTheScreen();
    expect(getByText('$15.99')).toBeOnTheScreen();

    await fireEvent.press(getByTestId('increase-cart-item-burger-1'));

    await waitFor(() => expect(useFoodCartStore.getState().items[0].quantity).toBe(2));
    expect(getByText('$26.99')).toBeOnTheScreen();

    await fireEvent.press(getByTestId('remove-cart-item-burger-1'));

    await waitFor(() => expect(useFoodCartStore.getState().items).toHaveLength(0));
    expect(getByText('Your cart is empty')).toBeOnTheScreen();
  });

  it('an empty cart has no checkout button, and "Browse restaurants" navigates back to the food catalog', async () => {
    const { getByText, queryByTestId } = await renderScreen();

    expect(getByText('Your cart is empty')).toBeOnTheScreen();
    expect(queryByTestId('cart-checkout')).toBeNull();

    await fireEvent.press(getByText('Browse restaurants'));

    expect(router.replace).toHaveBeenCalledWith(AppRoutes.food);
  });

  it('tapping continue navigates to checkout', async () => {
    const { getByTestId, getByText } = await renderScreen({ items: [burger] });

    expect(getByText('Continue to checkout • $15.99')).toBeOnTheScreen();
    await fireEvent.press(getByTestId('cart-checkout'));

    expect(router.push).toHaveBeenCalledWith(AppRoutes.foodCheckout);
  });

  it('disables decrease at a quantity of 1 and increase at the maximum quantity', async () => {
    const { getByTestId } = await renderScreen({ items: [burger] });

    expect(getByTestId('decrease-cart-item-burger-1')).toBeDisabled();
    expect(getByTestId('increase-cart-item-burger-1')).toBeEnabled();

    await act(async () => {
      useFoodCartStore.setState({ items: [{ ...burger, quantity: FOOD_CART_MAXIMUM_QUANTITY }] });
    });

    await waitFor(() => expect(getByTestId('increase-cart-item-burger-1')).toBeDisabled());
    expect(getByTestId('decrease-cart-item-burger-1')).toBeEnabled();

    await fireEvent.press(getByTestId('decrease-cart-item-burger-1'));
    await waitFor(() => expect(useFoodCartStore.getState().items[0].quantity).toBe(FOOD_CART_MAXIMUM_QUANTITY - 1));
  });

  it('Clear asks for confirmation, then empties the cart', async () => {
    const alertSpy = jest.spyOn(Alert, 'alert').mockImplementation(() => {});
    const { getByText, queryByText } = await renderScreen({ items: [burger] });

    await fireEvent.press(getByText('Clear'));

    expect(alertSpy).toHaveBeenCalledWith('Clear your cart?', expect.any(String), expect.any(Array));
    expect(useFoodCartStore.getState().items).toHaveLength(1);

    const buttons = alertSpy.mock.calls[0][2] as AlertButton[];
    await act(async () => {
      buttons.find((button) => button.text === 'Clear cart')!.onPress!();
    });

    await waitFor(() => expect(getByText('Your cart is empty')).toBeOnTheScreen());
    expect(useFoodCartStore.getState().items).toHaveLength(0);
    expect(queryByText('Clear')).toBeNull();
  });

  it('shows tax, delivery fee, and total as "Calculated at checkout" until pricing has loaded', async () => {
    const { getAllByText, getByText } = await renderScreen({ items: [burger], pricing: null });

    expect(getByText('Subtotal')).toBeOnTheScreen();
    // Tax, Delivery fee, and Total all pending.
    expect(getAllByText('Calculated at checkout')).toHaveLength(3);
    expect(getByText('Continue to checkout')).toBeOnTheScreen();
  });
});
