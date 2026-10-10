/**
 * Ports `flutter_app/test/restaurant_screen_test.dart` against the real
 * `RestaurantMenuScreen` (issue #383) -- the Dart file's three direct
 * `MenuItem.fromMap` price-parsing cases are ported instead against
 * `menuItemFromRow` in `../../../../../../features/food/api/
 * restaurant-menu-repository.test.ts` (this screen never calls that
 * function directly), and "menu cards grow for narrow screens and larger
 * text" is a Flutter `RenderBox` overflow-style layout assertion with no
 * React Native equivalent, same precedent as `food/index.test.tsx`'s own
 * "stays overflow-free" case.
 *
 * Follows `food/index.test.tsx`'s seam: this screen calls
 * `useRestaurantMenu` directly (no injected loader prop), which calls
 * `fetchMenu` with no injected client -- so the seam here is mocking
 * `restaurant-menu-repository.ts`'s `fetchMenu` export itself, the same way
 * `food/index.test.tsx` mocks `fetchCategories`/`fetchRestaurants`.
 *
 * `expo-router`'s imperative `router`/`useLocalSearchParams` and
 * `@/platform/supabase/client` are mocked the same way `food/index.test.tsx`
 * mocks them -- importing `@/stores/food-cart-store` (for the real
 * `useFoodCartStore` singleton, used below both to seed a restaurant
 * conflict and to assert what actually lands in the cart) transitively
 * pulls in the real Supabase client via `service-pricing-repository.ts`,
 * which reads env vars at import time.
 *
 * `@shopify/flash-list` has no existing test precedent in this repo to
 * follow (grep confirmed). It is mocked here with a plain, unvirtualized
 * stand-in that renders every row eagerly (header/items/footer/empty, like
 * `FlatList` under a test renderer) and exposes its imperative
 * `scrollToIndex` as a plain top-level `jest.fn()`. The real `FlashList`
 * does mount/render/scroll fine under `jest-expo` (confirmed separately),
 * but its `scrollToIndex` has no observable effect without a real native
 * layout pass, so there is no way to assert *which* index a real device
 * would land on without this same substitution -- this mock is the
 * FlashList-equivalent of this screen's own `categoryIndexById` index math,
 * asserted through the one imperative call that consumes it.
 *
 * `addToCart`'s own `await addToCartStore(...)` (and `useCartSnackbar`'s
 * `show`) update state after `fireEvent.press` has already returned (it
 * fires the async handler but does not await it), which logs React's "not
 * wrapped in act(...)" warning below each of those tests -- same
 * known-noisy-but-harmless tradeoff `food/index.test.tsx`'s own top comment
 * documents for its debounce case; the subsequent `waitFor` in each test
 * still correctly observes the settled result.
 */
import { QueryClient } from '@tanstack/react-query';
import { fireEvent, waitFor } from '@testing-library/react-native';
import { router, useLocalSearchParams } from 'expo-router';
import { Alert } from 'react-native';

import { renderWithProviders } from '@/test-utils';
import { fetchMenu } from '@/features/food/api/restaurant-menu-repository';
import type { RestaurantMenu } from '@/features/food/api/restaurant-menu';
import type { Restaurant } from '@/features/food/api/restaurant';
import { AppRoutes } from '@/platform/navigation/app-routes';
import { useFoodCartStore } from '@/stores/food-cart-store';

import RestaurantMenuScreen from './index';

jest.mock('expo-router', () => ({
  router: {
    push: jest.fn(),
    canGoBack: jest.fn(() => false),
    back: jest.fn(),
    replace: jest.fn(),
  },
  useLocalSearchParams: jest.fn(() => ({ restaurantId: 'restaurant-1' })),
}));

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

jest.mock('@/features/food/api/restaurant-menu-repository', () => ({
  fetchMenu: jest.fn(),
}));

// A plain, unvirtualized stand-in -- see this file's top comment for why.
jest.mock('@shopify/flash-list', () => {
  // `jest.mock` factories are hoisted above every import in this file, so
  // the module-scoped `React`/`View` imports above aren't reachable from
  // inside one -- same `require()`-inside-the-factory pattern (and reason)
  // as `use-food-home.test.tsx`'s own `@/platform/supabase/client` mock.
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const React = require('react');
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { View } = require('react-native');
  const scrollToIndex = jest.fn();
  const FlashListMock = React.forwardRef(function FlashListMock(props: any, ref: any) {
    React.useImperativeHandle(ref, () => ({ scrollToIndex }));
    return (
      <View testID={props.testID}>
        {props.ListHeaderComponent}
        {props.data.length === 0
          ? props.ListEmptyComponent
          : props.data.map((item: unknown, index: number) => (
              <View key={props.keyExtractor ? props.keyExtractor(item, index) : index}>{props.renderItem({ item, index })}</View>
            ))}
        {props.ListFooterComponent}
      </View>
    );
  });
  return { FlashList: FlashListMock, __mockScrollToIndex: scrollToIndex };
});

const mockFetchMenu = fetchMenu as jest.Mock;
const { __mockScrollToIndex: mockScrollToIndex } = jest.requireMock('@shopify/flash-list') as { __mockScrollToIndex: jest.Mock };

const restaurant: Restaurant = {
  id: 'restaurant-1',
  name: 'Test Kitchen',
  description: 'Fresh food made daily',
  logoUrl: '',
};

/** Mirrors the Dart test's `menu` fixture exactly (ids, names, prices). */
const menu: RestaurantMenu = {
  restaurant,
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
    {
      id: 'drinks',
      name: 'Drinks',
      items: [
        {
          id: 'drink-1',
          name: 'Fresh Lemonade',
          description: 'Lemon and mint',
          price: 100,
          imageUrl: '',
          categoryId: 'drinks',
        },
      ],
    },
  ],
};

const initialCartState = useFoodCartStore.getState();

// Every `QueryClient` `renderScreen()` below creates, so `afterEach` can
// `clear()` each one -- same reasoning as `food/index.test.tsx`'s own
// comment on avoiding a leaked gcTime cache-eviction timer.
const renderedQueryClients: QueryClient[] = [];

async function renderScreen() {
  const result = await renderWithProviders(<RestaurantMenuScreen />);
  renderedQueryClients.push(result.queryClient);
  return result;
}

beforeEach(() => {
  mockFetchMenu.mockReset();
  (useLocalSearchParams as jest.Mock).mockReturnValue({ restaurantId: 'restaurant-1' });
});

afterEach(() => {
  jest.clearAllMocks();
  useFoodCartStore.setState(initialCartState, true);
  renderedQueryClients.splice(0).forEach((client) => client.clear());
});

describe('RestaurantMenuScreen', () => {
  it('renders the restaurant header, categories (with sticky-style headers), and menu items once the menu loads', async () => {
    mockFetchMenu.mockResolvedValue(menu);

    const { getAllByText, getByText, getByTestId } = await renderScreen();

    await waitFor(() => expect(getByText('Classic Burger')).toBeOnTheScreen());

    // The restaurant name appears both in the hero app bar and the header
    // section below it.
    expect(getAllByText('Test Kitchen').length).toBeGreaterThanOrEqual(2);
    expect(getByText('2 items')).toBeOnTheScreen();
    expect(getByText('2 categories')).toBeOnTheScreen();

    // Category chips (CategoryChipBar) + category headers (MenuCategoryHeader,
    // rendered as sticky rows via the list's `stickyHeaderIndices`) both show
    // each category's name.
    expect(getByTestId('category-chip-burgers')).toBeOnTheScreen();
    expect(getByTestId('category-chip-drinks')).toBeOnTheScreen();
    expect(getAllByText('Burgers').length).toBeGreaterThanOrEqual(2);
    expect(getAllByText('Drinks').length).toBeGreaterThanOrEqual(2);
    expect(getAllByText('1 item').length).toBe(2);

    expect(getByText('Classic Burger')).toBeOnTheScreen();
    expect(getByText('$5.50')).toBeOnTheScreen();
    expect(getByText('Fresh Lemonade')).toBeOnTheScreen();
    expect(getByText('$1.00')).toBeOnTheScreen();
  });

  it('tapping a category chip scrolls the menu list to that category', async () => {
    mockFetchMenu.mockResolvedValue(menu);

    const { getByText, getByTestId } = await renderScreen();
    await waitFor(() => expect(getByText('Classic Burger')).toBeOnTheScreen());

    await fireEvent.press(getByTestId('category-chip-drinks'));

    // rows = [burgers-header(0), burger-1(1), drinks-header(2), drink-1(3)]
    // -- tapping "Drinks" should scroll to its own header's row index.
    expect(mockScrollToIndex).toHaveBeenCalledWith({ index: 2, animated: true });
  });

  it('adds a menu item to the food cart store and shows a confirmation', async () => {
    mockFetchMenu.mockResolvedValue(menu);

    const { getByText, getByLabelText } = await renderScreen();
    await waitFor(() => expect(getByText('Classic Burger')).toBeOnTheScreen());

    await fireEvent.press(getByLabelText('Add Classic Burger to cart'));

    await waitFor(() => expect(getByText('Classic Burger added to cart')).toBeOnTheScreen());
    expect(useFoodCartStore.getState().items).toEqual([
      expect.objectContaining({ menuItemId: 'burger-1', restaurantId: 'restaurant-1', restaurantName: 'Test Kitchen', quantity: 1 }),
    ]);
  });

  it(
    'confirms before replacing a different restaurant\'s cart, and "Start new cart" replaces it',
    async () => {
      mockFetchMenu.mockResolvedValue(menu);
      useFoodCartStore.setState({
        items: [
          {
            menuItemId: 'other-1',
            restaurantId: 'other-restaurant',
            restaurantName: 'Other Place',
            name: 'Taco',
            unitPrice: 300,
            imageUrl: '',
            quantity: 1,
          },
        ],
      });
      const alertSpy = jest.spyOn(Alert, 'alert').mockImplementation(() => {});

      const { getByText, getByLabelText } = await renderScreen();
      await waitFor(() => expect(getByText('Classic Burger')).toBeOnTheScreen());

      await fireEvent.press(getByLabelText('Add Classic Burger to cart'));

      expect(alertSpy).toHaveBeenCalledTimes(1);
      const [title, message, buttons] = alertSpy.mock.calls[0];
      expect(title).toBe('Start a new cart?');
      expect(message).toBe('Your cart contains items from Other Place. Starting a cart from Test Kitchen will remove them.');
      expect(buttons).toEqual([
        { text: 'Keep cart', style: 'cancel' },
        { text: 'Start new cart', style: 'destructive', onPress: expect.any(Function) },
      ]);
      // Nothing changes until the destructive action is actually pressed.
      expect(useFoodCartStore.getState().items).toHaveLength(1);
      expect(useFoodCartStore.getState().items[0].restaurantId).toBe('other-restaurant');

      await buttons?.[1]?.onPress?.();

      await waitFor(() => expect(getByText('New cart started with Classic Burger')).toBeOnTheScreen());
      expect(useFoodCartStore.getState().items).toEqual([
        expect.objectContaining({ menuItemId: 'burger-1', restaurantId: 'restaurant-1', quantity: 1 }),
      ]);

      alertSpy.mockRestore();
    },
  );

  it('shows the cart FAB only once the cart holds items, and navigates to the food cart on tap', async () => {
    mockFetchMenu.mockResolvedValue(menu);

    const { getByText, getByLabelText, getByTestId, queryByTestId } = await renderScreen();
    await waitFor(() => expect(getByText('Classic Burger')).toBeOnTheScreen());

    expect(queryByTestId('restaurant-cart-fab')).toBeNull();

    await fireEvent.press(getByLabelText('Add Classic Burger to cart'));
    await waitFor(() => expect(getByTestId('restaurant-cart-fab')).toBeOnTheScreen());
    expect(getByLabelText('Food cart (1)')).toBeOnTheScreen();

    await fireEvent.press(getByTestId('restaurant-cart-fab'));

    expect(router.push).toHaveBeenCalledWith(AppRoutes.foodCart);
  });

  it('shows the empty state when the menu has no categories', async () => {
    mockFetchMenu.mockResolvedValue({ restaurant, categories: [] });

    const { getByTestId, getByText, queryByTestId } = await renderScreen();

    await waitFor(() => expect(getByTestId('empty-state')).toBeOnTheScreen());
    expect(getByText('No menu items yet')).toBeOnTheScreen();
    expect(getByText('0 items')).toBeOnTheScreen();
    expect(getByText('0 categories')).toBeOnTheScreen();
    expect(queryByTestId('category-chip-burgers')).toBeNull();
  });

  it('shows an ErrorState with a working retry on a first load that fails', async () => {
    mockFetchMenu.mockRejectedValueOnce(new Error('offline'));

    const { getByTestId, getByText, queryByTestId } = await renderScreen();

    await waitFor(() => expect(getByTestId('error-state')).toBeOnTheScreen());
    expect(getByText('We could not load this menu.')).toBeOnTheScreen();

    mockFetchMenu.mockResolvedValueOnce(menu);
    await fireEvent.press(getByText('Try again'));

    await waitFor(() => expect(queryByTestId('error-state')).toBeNull());
    expect(getByText('Classic Burger')).toBeOnTheScreen();
  });

  it('falls back to router.replace from the error state\'s back button when there is nothing to go back to', async () => {
    (router.canGoBack as jest.Mock).mockReturnValue(false);
    mockFetchMenu.mockRejectedValueOnce(new Error('offline'));

    const { getByTestId, getByLabelText } = await renderScreen();
    await waitFor(() => expect(getByTestId('error-state')).toBeOnTheScreen());

    await fireEvent.press(getByLabelText('Back'));

    expect(router.replace).toHaveBeenCalledWith('/');
    expect(router.back).not.toHaveBeenCalled();
  });

  it('pops with router.back from the loaded header\'s back button when it can go back', async () => {
    (router.canGoBack as jest.Mock).mockReturnValue(true);
    mockFetchMenu.mockResolvedValue(menu);

    const { getByText, getByLabelText } = await renderScreen();
    await waitFor(() => expect(getByText('Classic Burger')).toBeOnTheScreen());

    await fireEvent.press(getByLabelText('Back'));

    expect(router.back).toHaveBeenCalledTimes(1);
    expect(router.replace).not.toHaveBeenCalled();
  });
});
