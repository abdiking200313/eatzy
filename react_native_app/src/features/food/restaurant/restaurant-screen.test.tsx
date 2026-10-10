/**
 * Ports the widget cases of `flutter_app/test/restaurant_screen_test.dart`
 * against the real `RestaurantScreen` (issue #383); the model cases live in
 * `src/features/food/api/restaurant-menu.test.ts`.
 *
 * Seams (same posture as `src/app/(app)/(tabs)/food/index.test.tsx`): the
 * Dart test's injected `menuLoader`/`locationRepository` become mocks of
 * `fetchRestaurantMenu`/`fetchRestaurantLocations`, and its injected
 * `CartController` becomes the real `useFoodCartStore` singleton, reset
 * after each test.
 *
 * Not ported as-is:
 * - The SnackBar `behavior`/`margin` assertions are Flutter-widget
 *   specifics; the confirmation's existence and its auto-dismiss (well
 *   under Flutter's 4s default) are still asserted.
 * - "menu cards grow for narrow screens and larger text" is a Flutter
 *   `RenderFlex` overflow check with no React Native equivalent (same
 *   precedent as `food/index.test.tsx`); the card is still rendered with
 *   the same long name/description to prove it mounts and shows them.
 */
import { act, fireEvent, render, waitFor } from '@testing-library/react-native';
import { router } from 'expo-router';
import { Alert } from 'react-native';
import { QueryClient } from '@tanstack/react-query';

import { renderWithProviders } from '@/test-utils';
import { fetchRestaurantLocations, type RestaurantLocation } from '@/features/food/api/restaurant-location';
import type { MenuItem, RestaurantMenu } from '@/features/food/api/restaurant-menu';
import { fetchRestaurantMenu } from '@/features/food/api/restaurant-menu-repository';
import { AppRoutes } from '@/platform/navigation/app-routes';
import { useFoodCartStore } from '@/stores/food-cart-store';

import { MenuItemCard } from './menu-item-card';
import { addToCartMessage, RestaurantScreen } from './restaurant-screen';

jest.mock('expo-router', () => ({
  router: { push: jest.fn(), back: jest.fn(), replace: jest.fn(), canGoBack: jest.fn(() => true) },
}));

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

jest.mock('@/features/food/api/restaurant-menu-repository', () => ({
  fetchRestaurantMenu: jest.fn(),
}));

jest.mock('@/features/food/api/restaurant-location', () => ({
  fetchRestaurantLocations: jest.fn(),
}));

const mockFetchMenu = fetchRestaurantMenu as jest.Mock;
const mockFetchLocations = fetchRestaurantLocations as jest.Mock;

const burger: MenuItem = {
  id: 'burger-1',
  name: 'Classic Burger',
  description: 'Beef, cheese, and house sauce',
  price: 550,
  imageUrl: '',
  categoryId: 'burgers',
};
const lemonade: MenuItem = {
  id: 'drink-1',
  name: 'Fresh Lemonade',
  description: 'Lemon and mint',
  price: 100,
  imageUrl: '',
  categoryId: 'drinks',
};

const menu: RestaurantMenu = {
  restaurant: { id: 'restaurant-1', name: 'Test Kitchen', description: 'Fresh food made daily', logoUrl: '' },
  categories: [
    { id: 'burgers', name: 'Burgers', items: [burger] },
    { id: 'drinks', name: 'Drinks', items: [lemonade] },
  ],
};

const renderedQueryClients: QueryClient[] = [];

async function renderScreen() {
  const result = await renderWithProviders(<RestaurantScreen restaurantId="restaurant-1" />);
  renderedQueryClients.push(result.queryClient);
  return result;
}

const initialCartState = useFoodCartStore.getState();

beforeEach(() => {
  mockFetchMenu.mockReset().mockResolvedValue(menu);
  mockFetchLocations.mockReset().mockResolvedValue([]);
  (router.push as jest.Mock).mockClear();
  (router.back as jest.Mock).mockClear();
});

afterEach(() => {
  useFoodCartStore.setState(initialCartState, true);
  renderedQueryClients.splice(0).forEach((client) => client.clear());
  jest.restoreAllMocks();
});

describe('RestaurantScreen', () => {
  it('groups and navigates categorized items, and adds to cart with a short-lived confirmation', async () => {
    const { getAllByText, getByText, getByLabelText, queryByText } = await renderScreen();

    await waitFor(() => expect(getByText('2 items')).toBeOnTheScreen());
    expect(mockFetchMenu).toHaveBeenCalledWith('restaurant-1');
    expect(getAllByText('Test Kitchen').length).toBeGreaterThan(0);
    expect(getByText('2 categories')).toBeOnTheScreen();
    expect(getByText('Classic Burger')).toBeOnTheScreen();
    expect(getByText('$5.50')).toBeOnTheScreen();
    expect(getByLabelText('Burgers')).toBeOnTheScreen();
    expect(getByLabelText('Drinks')).toBeOnTheScreen();
    // The first chip is selected by default.
    expect(getByLabelText('Burgers').props.accessibilityState).toEqual({ selected: true });

    await fireEvent.press(getByLabelText('Add Classic Burger to cart'));

    await waitFor(() => expect(getByText('Classic Burger added to cart')).toBeOnTheScreen());
    expect(useFoodCartStore.getState().items).toHaveLength(1);
    expect(useFoodCartStore.getState().items[0]).toMatchObject({
      menuItemId: 'burger-1',
      restaurantId: 'restaurant-1',
      restaurantName: 'Test Kitchen',
      unitPrice: 550,
      quantity: 1,
    });

    // Auto-dismisses well before Flutter's 4-second SnackBar default.
    await waitFor(() => expect(queryByText('Classic Burger added to cart')).toBeNull(), { timeout: 3000 });

    await fireEvent.press(getByLabelText('Drinks'));

    expect(getByLabelText('Drinks').props.accessibilityState).toEqual({ selected: true });
    expect(getByText('Fresh Lemonade')).toBeOnTheScreen();
    expect(getByText('$1.00')).toBeOnTheScreen();
  });

  it('shows a useful menu error, and retries', async () => {
    mockFetchMenu.mockRejectedValue(new Error('failed'));

    const { getByText, queryByText } = await renderScreen();

    await waitFor(() => expect(getByText('We could not load this menu')).toBeOnTheScreen());
    expect(getByText('Try again')).toBeOnTheScreen();

    mockFetchMenu.mockResolvedValue(menu);
    await fireEvent.press(getByText('Try again'));

    await waitFor(() => expect(getByText('Classic Burger')).toBeOnTheScreen());
    expect(queryByText('We could not load this menu')).toBeNull();
  });

  it('shows the loading caption until the menu arrives', async () => {
    let resolveMenu!: (value: RestaurantMenu) => void;
    mockFetchMenu.mockReturnValue(new Promise<RestaurantMenu>((resolve) => (resolveMenu = resolve)));

    const { getByText, queryByText } = await renderScreen();

    expect(getByText('Loading menu…')).toBeOnTheScreen();

    resolveMenu(menu);
    await waitFor(() => expect(getByText('Classic Burger')).toBeOnTheScreen());
    expect(queryByText('Loading menu…')).toBeNull();
  });

  it('shows the empty view for a menu with no categories', async () => {
    mockFetchMenu.mockResolvedValue({ ...menu, categories: [] });

    const { getByText, queryByTestId } = await renderScreen();

    await waitFor(() => expect(getByText('No menu items yet')).toBeOnTheScreen());
    expect(getByText('0 items')).toBeOnTheScreen();
    expect(queryByTestId('category-chip-bar')).toBeNull();
  });

  it("lists the restaurant's locations once they load", async () => {
    const locations: RestaurantLocation[] = [
      { id: 'l1', restaurantId: 'restaurant-1', storeName: 'Bakara', phoneNumber: null, latitude: null, longitude: null, mapcode: null, mapcodeTerritory: null },
      { id: 'l2', restaurantId: 'restaurant-1', storeName: 'Hodan', phoneNumber: null, latitude: null, longitude: null, mapcode: null, mapcodeTerritory: null },
    ];
    mockFetchLocations.mockResolvedValue(locations);

    const { getByText } = await renderScreen();

    await waitFor(() => expect(getByText('Bakara • Hodan')).toBeOnTheScreen());
  });

  it('hides the location line when locations fail to load', async () => {
    mockFetchLocations.mockRejectedValue(new Error('offline'));

    const { getByText, queryByTestId } = await renderScreen();

    await waitFor(() => expect(getByText('Classic Burger')).toBeOnTheScreen());
    await waitFor(() => expect(mockFetchLocations).toHaveBeenCalledWith('restaurant-1'));
    expect(queryByTestId('restaurant-locations')).toBeNull();
  });

  it('asks before replacing a cart from another restaurant, and keeps it on "Keep cart"', async () => {
    useFoodCartStore.setState({
      items: [
        { menuItemId: 'x', restaurantId: 'other', restaurantName: 'Other Place', name: 'Rice', unitPrice: 300, imageUrl: '', quantity: 1 },
      ],
    });
    const alertSpy = jest.spyOn(Alert, 'alert').mockImplementation((_title, _message, buttons) => {
      buttons?.find((button) => button.text === 'Keep cart')?.onPress?.();
    });

    const { getByLabelText, getByText } = await renderScreen();
    await waitFor(() => expect(getByText('Classic Burger')).toBeOnTheScreen());

    await fireEvent.press(getByLabelText('Add Classic Burger to cart'));

    await waitFor(() => expect(alertSpy).toHaveBeenCalled());
    expect(alertSpy.mock.calls[0][0]).toBe('Start a new cart?');
    expect(alertSpy.mock.calls[0][1]).toBe(
      'Your cart contains items from Other Place. Starting a cart from Test Kitchen will remove them.',
    );
    expect(useFoodCartStore.getState().items.map((item) => item.menuItemId)).toEqual(['x']);
  });

  it('starts a new cart on "Start new cart"', async () => {
    useFoodCartStore.setState({
      items: [
        { menuItemId: 'x', restaurantId: 'other', restaurantName: 'Other Place', name: 'Rice', unitPrice: 300, imageUrl: '', quantity: 1 },
      ],
    });
    jest.spyOn(Alert, 'alert').mockImplementation((_title, _message, buttons) => {
      buttons?.find((button) => button.text === 'Start new cart')?.onPress?.();
    });

    const { getByLabelText, getByText } = await renderScreen();
    await waitFor(() => expect(getByText('Classic Burger')).toBeOnTheScreen());

    await fireEvent.press(getByLabelText('Add Classic Burger to cart'));

    await waitFor(() => expect(getByText('New cart started with Classic Burger')).toBeOnTheScreen());
    expect(useFoodCartStore.getState().items.map((item) => item.menuItemId)).toEqual(['burger-1']);
  });

  it('shows the View cart button only with items, and opens the food cart', async () => {
    const { getByLabelText, getByText, queryByText } = await renderScreen();
    await waitFor(() => expect(getByText('Classic Burger')).toBeOnTheScreen());
    expect(queryByText('View cart')).toBeNull();

    await fireEvent.press(getByLabelText('Add Classic Burger to cart'));

    await waitFor(() => expect(getByLabelText('View cart (1)')).toBeOnTheScreen());
    await fireEvent.press(getByLabelText('View cart (1)'));
    expect(router.push).toHaveBeenCalledWith(AppRoutes.foodCart);
  });

  it("opens an item's details route when its card is tapped", async () => {
    const { getByTestId, getByText } = await renderScreen();
    await waitFor(() => expect(getByText('Classic Burger')).toBeOnTheScreen());

    await fireEvent.press(getByTestId('menu-item-burger-1'));

    expect(router.push).toHaveBeenCalledWith('/food/restaurants/restaurant-1/item/burger-1');
  });

  it('goes back from the hero back button', async () => {
    const { getByLabelText, getByText } = await renderScreen();
    await waitFor(() => expect(getByText('Classic Burger')).toBeOnTheScreen());

    await fireEvent.press(getByLabelText('Back'));

    expect(router.back).toHaveBeenCalled();
  });
});

describe('addToCartMessage', () => {
  it.each([
    ['added', 1, 'Classic Burger added to cart'],
    ['added', 2, '2× Classic Burger added to cart'],
    ['quantityIncreased', 1, 'Classic Burger quantity increased'],
    ['replacedRestaurant', 3, 'New cart started with 3× Classic Burger'],
    ['maximumReached', 2, 'Classic Burger is already at the maximum quantity'],
  ] as const)('%s x%d -> %s', (result, quantity, expected) => {
    expect(addToCartMessage(result, burger, quantity)).toBe(expected);
  });
});

describe('MenuItemCard', () => {
  it('renders a long name and description and adds one unit', async () => {
    const longItem: MenuItem = {
      id: 'long-item',
      name: 'A generously filled traditional Somali family platter',
      description: 'Slow-cooked ingredients with fresh vegetables and house spices.',
      price: 1250,
      imageUrl: '',
      categoryId: 'mains',
    };
    const onAddToCart = jest.fn();

    const { getByText, getByLabelText } = await render(
      <MenuItemCard item={longItem} onPress={() => {}} onAddToCart={onAddToCart} />,
    );

    expect(getByText(longItem.name)).toBeOnTheScreen();
    expect(getByText(longItem.description)).toBeOnTheScreen();
    expect(getByText('$12.50')).toBeOnTheScreen();

    await act(async () => {
      fireEvent.press(getByLabelText(`Add ${longItem.name} to cart`));
    });
    expect(onAddToCart).toHaveBeenCalledWith(1);
  });
});
