/**
 * Covers `MenuItemDetailsScreen` (issue #384), using the same seams as the
 * sibling restaurant screen's `../index.test.tsx`: `fetchMenu` is mocked
 * (the screen reads the menu through `useRestaurantMenu`), `expo-router` and
 * `@/platform/supabase/client` are mocked, and the real `useFoodCartStore`
 * singleton is used so the test observes what actually lands in the cart and
 * in (mocked) AsyncStorage.
 */
import AsyncStorage from '@react-native-async-storage/async-storage';
import { QueryClient } from '@tanstack/react-query';
import { act, fireEvent, waitFor } from '@testing-library/react-native';
import { router, useLocalSearchParams } from 'expo-router';
import { Alert } from 'react-native';

import { renderWithProviders } from '@/test-utils';
import { fetchMenu } from '@/features/food/api/restaurant-menu-repository';
import type { RestaurantMenu } from '@/features/food/api/restaurant-menu';
import { FOOD_CART_KEY_PREFIX, selectFoodCartItemCount, useFoodCartStore } from '@/stores/food-cart-store';

import MenuItemDetailsScreen from './[itemId]';

jest.mock('expo-router', () => ({
  router: {
    push: jest.fn(),
    canGoBack: jest.fn(() => true),
    back: jest.fn(),
    replace: jest.fn(),
  },
  useLocalSearchParams: jest.fn(() => ({ restaurantId: 'restaurant-1', itemId: 'burger-1' })),
}));

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

jest.mock('@/features/food/api/restaurant-menu-repository', () => ({
  fetchMenu: jest.fn(),
}));

const mockFetchMenu = fetchMenu as jest.Mock;

const menu: RestaurantMenu = {
  restaurant: { id: 'restaurant-1', name: 'Test Kitchen', description: 'Fresh food made daily', logoUrl: '' },
  categories: [
    {
      id: 'burgers',
      name: 'Burgers',
      items: [
        {
          id: 'burger-1',
          name: 'Classic Burger',
          description: 'Beef, cheese, and house sauce',
          price: 550,
          imageUrl: '',
          categoryId: 'burgers',
        },
      ],
    },
  ],
};

const initialCartState = useFoodCartStore.getState();
const renderedQueryClients: QueryClient[] = [];

async function renderScreen() {
  const result = await renderWithProviders(<MenuItemDetailsScreen />);
  renderedQueryClients.push(result.queryClient);
  return result;
}

beforeEach(async () => {
  mockFetchMenu.mockReset();
  (useLocalSearchParams as jest.Mock).mockReturnValue({ restaurantId: 'restaurant-1', itemId: 'burger-1' });
  await AsyncStorage.clear();
});

afterEach(() => {
  jest.clearAllMocks();
  useFoodCartStore.setState(initialCartState, true);
  renderedQueryClients.splice(0).forEach((client) => client.clear());
});

describe('MenuItemDetailsScreen', () => {
  it('shows the item name, price, and description once the menu loads', async () => {
    mockFetchMenu.mockResolvedValue(menu);

    const { getByText } = await renderScreen();

    await waitFor(() => expect(getByText('Classic Burger')).toBeOnTheScreen());
    expect(getByText('$5.50')).toBeOnTheScreen();
    expect(getByText('Beef, cheese, and house sauce')).toBeOnTheScreen();
    expect(mockFetchMenu).toHaveBeenCalledWith('restaurant-1');
  });

  it('adds the chosen quantity to the food cart, updates the badge count, and persists it', async () => {
    mockFetchMenu.mockResolvedValue(menu);

    const { getByText, getByLabelText } = await renderScreen();
    await waitFor(() => expect(getByText('Classic Burger')).toBeOnTheScreen());

    await fireEvent.press(getByLabelText('Increase quantity'));
    await fireEvent.press(getByLabelText('Increase quantity'));
    await fireEvent.press(getByText('Add to cart'));

    expect(router.back).toHaveBeenCalled();
    await waitFor(() => expect(selectFoodCartItemCount(useFoodCartStore.getState().items)).toBe(3));
    expect(useFoodCartStore.getState().items[0]).toMatchObject({
      menuItemId: 'burger-1',
      restaurantId: 'restaurant-1',
      restaurantName: 'Test Kitchen',
      unitPrice: 550,
      quantity: 3,
    });

    // `persist()` is awaited inside `addItem`, so once the store holds the
    // item the AsyncStorage write has been issued; flush it before reading.
    await waitFor(() => expect(useFoodCartStore.getState().items).toHaveLength(1));
    const keys = await AsyncStorage.getAllKeys();
    const cartKey = keys.find((key) => key.startsWith(FOOD_CART_KEY_PREFIX));
    expect(cartKey).toBeDefined();
    expect(await AsyncStorage.getItem(cartKey!)).toContain('burger-1');
  });

  it('asks before replacing a cart from another restaurant', async () => {
    mockFetchMenu.mockResolvedValue(menu);
    useFoodCartStore.setState({
      items: [
        {
          menuItemId: 'other-item',
          restaurantId: 'restaurant-2',
          restaurantName: 'Other Place',
          name: 'Taco',
          unitPrice: 300,
          imageUrl: '',
          quantity: 1,
        },
      ],
    });
    const alertSpy = jest.spyOn(Alert, 'alert').mockImplementation(() => {});

    const { getByText } = await renderScreen();
    await waitFor(() => expect(getByText('Classic Burger')).toBeOnTheScreen());
    await fireEvent.press(getByText('Add to cart'));

    await waitFor(() => expect(alertSpy).toHaveBeenCalled());
    const [title, message, buttons] = alertSpy.mock.calls[0];
    expect(title).toBe('Start a new cart?');
    expect(message).toContain('Other Place');
    expect(useFoodCartStore.getState().items[0].restaurantId).toBe('restaurant-2');

    const startNew = buttons!.find((button) => button.text === 'Start new cart');
    await act(async () => startNew!.onPress!());
    await waitFor(() => expect(useFoodCartStore.getState().items[0]?.menuItemId).toBe('burger-1'));
    expect(useFoodCartStore.getState().items).toHaveLength(1);
    alertSpy.mockRestore();
  });

  it('shows a not-available message for an item id missing from the menu', async () => {
    mockFetchMenu.mockResolvedValue(menu);
    (useLocalSearchParams as jest.Mock).mockReturnValue({ restaurantId: 'restaurant-1', itemId: 'missing' });

    const { getByText } = await renderScreen();

    await waitFor(() => expect(getByText('This item is no longer available.')).toBeOnTheScreen());
  });

  it('shows a retryable error when the menu fails to load', async () => {
    mockFetchMenu.mockRejectedValue(new Error('offline'));

    const { getByText } = await renderScreen();

    await waitFor(() => expect(getByText('This item could not be loaded.')).toBeOnTheScreen());
    mockFetchMenu.mockResolvedValue(menu);
    await fireEvent.press(getByText('Try again'));
    await waitFor(() => expect(getByText('Classic Burger')).toBeOnTheScreen());
  });
});
