/**
 * Ports `flutter_app/test/food_home_screen_test.dart` against the real
 * `FoodHomeScreen` (issue #382) -- `food_controller_test.dart` (the
 * checkout cart controller) is a different file, unrelated to this screen,
 * and is not ported here.
 *
 * Not ported: "food home stays overflow-free on a narrow, large-text
 * screen" -- a Flutter `RenderFlex` overflow assertion with no React
 * Native equivalent (RN's flexbox layout doesn't fail the same way), same
 * precedent as `../explore.test.tsx`/`../services.test.tsx`.
 *
 * Unlike `ExploreScreen` (a `storeListingLoader`-prop test seam), this
 * screen has no injected loader props of its own -- it calls `useFoodHome`/
 * `useFoodRestaurantSearch` directly, which call `fetchCategories`/
 * `fetchRestaurants` with no injected client. The seam here is mocking
 * `category-repository.ts`/`restaurant-repository.ts` themselves (both
 * named exports replaced with `jest.fn()`s, then driven per test via
 * `mockResolvedValue`/`mockImplementation`), standing in for the Dart
 * test's injected `categoryLoader`/`restaurantLoader`/`restaurantQuery`
 * constructor params. `fetchRestaurants` backs both `useFoodHome`'s
 * unfiltered call (made with no arguments) and `useFoodRestaurantSearch`'s
 * filtered call (always made with an options object) -- the shared mock
 * below branches on that the same way the Dart test's separate
 * `restaurantLoader`/`restaurantQuery` callbacks do.
 *
 * `expo-router`'s imperative `router` and `@/platform/supabase/client` are
 * mocked the same way `explore.test.tsx`/`food-cart-store.test.ts` mock
 * them -- this screen only ever calls `router.push` (never `useRouter()`/
 * `<Link>`), and importing `@/stores/food-cart-store` (for the real
 * `useFoodCartStore` singleton, used below to seed the cart-badge count)
 * transitively pulls in the real Supabase client, which reads env vars at
 * import time.
 *
 * The debounce case uses real timers plus a real (short) wall-clock wait
 * rather than `jest.useFakeTimers()` -- advancing fake timers while a deep
 * tree (`AppScaffold`/`FlatList`/`CategoryCard`'s own image-loading state,
 * etc.) is mounted triggered React's "overlapping act() calls" warning
 * here (sinon's fake-timer `tick()` flushes microtasks synchronously
 * mid-render), which isn't worth fighting for one test -- a real ~450ms
 * wait is negligible for this suite's runtime.
 */
import { QueryClient } from '@tanstack/react-query';
import { fireEvent, waitFor } from '@testing-library/react-native';
import { router } from 'expo-router';

import { renderWithProviders } from '@/test-utils';
import { fetchCategories } from '@/features/food/api/category-repository';
import type { Category } from '@/features/food/api/category';
import { fetchRestaurants, type FetchRestaurantsOptions } from '@/features/food/api/restaurant-repository';
import type { Restaurant } from '@/features/food/api/restaurant';
import { FOOD_SEARCH_DEBOUNCE_MS } from '@/features/food/api/use-food-restaurant-search';
import { AppRoutes } from '@/platform/navigation/app-routes';
import { useFoodCartStore, type CartItem } from '@/stores/food-cart-store';

import FoodHomeScreen from './index';

jest.mock('expo-router', () => ({
  router: { push: jest.fn() },
}));

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

jest.mock('@/features/food/api/category-repository', () => ({
  fetchCategories: jest.fn(),
}));

jest.mock('@/features/food/api/restaurant-repository', () => ({
  fetchRestaurants: jest.fn(),
}));

const mockFetchCategories = fetchCategories as jest.Mock;
const mockFetchRestaurants = fetchRestaurants as jest.Mock;

const riceCategory: Category = { id: 'rice', name: 'Rice', iconUrl: '' };
const grillCategory: Category = { id: 'grill', name: 'Grill', iconUrl: '' };

const mogadishuKitchen: Restaurant = {
  id: 'restaurant-1',
  name: 'Mogadishu Kitchen',
  description: 'Somali favourites',
  logoUrl: '',
};
const riceBowl: Restaurant = { id: 'restaurant-2', name: 'Rice Bowl', description: 'Rice specialists', logoUrl: '' };
const kitchenExpress: Restaurant = { id: 'restaurant-3', name: 'Kitchen Express', description: 'Fast Somali food', logoUrl: '' };

/** The unfiltered home call is always made with zero arguments -- distinguishes it from a search/category-filtered call below. */
function mockHomeRestaurants(restaurants: Restaurant[]) {
  mockFetchRestaurants.mockImplementation(async (options?: FetchRestaurantsOptions) => {
    if (!options) return restaurants;
    return [];
  });
}

/**
 * A real wall-clock wait -- see this file's top comment on why the
 * debounce case avoids `jest.useFakeTimers()`. The debounce timer's (and
 * TanStack Query's `notifyManager`'s) state update that fires sometime
 * during this real span logs React's "not wrapped in act(...)" warning
 * rather than failing anything -- the subsequent `waitFor` below still
 * correctly observes the settled result either way, and wrapping this in
 * an async `act()` was tried and made things *less* reliable (it left
 * later tests in this file unable to find even their own unrelated
 * content), so it's left as a plain wait with a known-noisy console
 * instead.
 */
function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Every `QueryClient` `renderScreen()` below creates, so `afterEach` can
// `clear()` each one -- otherwise each client's default `gcTime` leaves a
// pending cache-eviction timer behind, and Jest reports "did not exit" for
// a leaked timer (same reasoning as `use-food-home.test.tsx`'s own comment
// on this).
const renderedQueryClients: QueryClient[] = [];

/** Renders `FoodHomeScreen`, tracking its `QueryClient` for cleanup -- see `renderedQueryClients` above. */
async function renderScreen() {
  const result = await renderWithProviders(<FoodHomeScreen />);
  renderedQueryClients.push(result.queryClient);
  return result;
}

const initialCartState = useFoodCartStore.getState();

beforeEach(() => {
  mockFetchCategories.mockReset().mockResolvedValue([]);
  mockFetchRestaurants.mockReset();
  mockHomeRestaurants([]);
  (router.push as jest.Mock).mockClear();
});

afterEach(() => {
  useFoodCartStore.setState(initialCartState, true);
  renderedQueryClients.splice(0).forEach((client) => client.clear());
});

describe('FoodHomeScreen', () => {
  it('shows a loading state until both categories and restaurants have loaded', async () => {
    let resolveCategories!: (value: Category[]) => void;
    let resolveRestaurants!: (value: Restaurant[]) => void;
    mockFetchCategories.mockReturnValue(new Promise<Category[]>((resolve) => (resolveCategories = resolve)));
    mockFetchRestaurants.mockImplementation(() => new Promise<Restaurant[]>((resolve) => (resolveRestaurants = resolve)));

    const { getByTestId, getByText, queryByText, queryByTestId } = await renderScreen();

    expect(getByTestId('loading-state')).toBeOnTheScreen();

    resolveCategories([riceCategory]);
    // `loadFoodHome` awaits `Promise.all([fetchCategories(), fetchRestaurants()])`
    // -- resolving just one half doesn't settle the combined query yet, so
    // nothing re-renders here regardless.
    expect(getByTestId('loading-state')).toBeOnTheScreen();
    expect(queryByText('Rice')).toBeNull();

    resolveRestaurants([mogadishuKitchen]);

    await waitFor(() => expect(queryByTestId('loading-state')).toBeNull());
    expect(getByText('Rice')).toBeOnTheScreen();
    expect(getByText('Mogadishu Kitchen')).toBeOnTheScreen();
  });

  it('tapping a category chip runs a real, server-side filter; tapping it again clears it', async () => {
    mockFetchCategories.mockResolvedValue([riceCategory, grillCategory]);
    mockHomeRestaurants([mogadishuKitchen]);
    mockFetchRestaurants.mockImplementation(async (options?: FetchRestaurantsOptions) => {
      if (!options) return [mogadishuKitchen];
      if (options.categoryId === 'rice') return [riceBowl];
      return [];
    });

    const { getByText, getByLabelText, queryByText } = await renderScreen();

    // Before selecting a category, the unfiltered list is shown as-is.
    await waitFor(() => expect(getByText('Mogadishu Kitchen')).toBeOnTheScreen());
    expect(mockFetchRestaurants).toHaveBeenCalledTimes(1);

    await fireEvent.press(getByLabelText('Rice'));

    await waitFor(() => expect(getByText('Rice Bowl')).toBeOnTheScreen());
    expect(queryByText('Mogadishu Kitchen')).toBeNull();
    expect(mockFetchRestaurants).toHaveBeenLastCalledWith({ searchQuery: undefined, categoryId: 'rice' });

    // Tapping the same chip again clears the filter.
    await fireEvent.press(getByLabelText('Rice'));

    await waitFor(() => expect(getByText('Mogadishu Kitchen')).toBeOnTheScreen());
    expect(queryByText('Rice Bowl')).toBeNull();
  });

  it('typing a search term debounces before filtering, and the clear button clears it immediately', async () => {
    mockHomeRestaurants([mogadishuKitchen]);
    mockFetchRestaurants.mockImplementation(async (options?: FetchRestaurantsOptions) => {
      if (!options) return [mogadishuKitchen];
      return [kitchenExpress];
    });

    const { getByText, getByPlaceholderText, getByLabelText, queryByText } = await renderScreen();

    await waitFor(() => expect(getByText('Mogadishu Kitchen')).toBeOnTheScreen());
    expect(mockFetchRestaurants).toHaveBeenCalledTimes(1);

    fireEvent.changeText(getByPlaceholderText('Search restaurants...'), 'kitchen');

    // Still within the debounce window -- no new query fired yet.
    await sleep(100);
    expect(mockFetchRestaurants).toHaveBeenCalledTimes(1);
    expect(getByText('Mogadishu Kitchen')).toBeOnTheScreen();

    await sleep(FOOD_SEARCH_DEBOUNCE_MS);

    await waitFor(() => expect(getByText('Kitchen Express')).toBeOnTheScreen());
    expect(queryByText('Mogadishu Kitchen')).toBeNull();
    expect(mockFetchRestaurants).toHaveBeenLastCalledWith({ searchQuery: 'kitchen', categoryId: undefined });

    await fireEvent.press(getByLabelText('Clear'));

    // Clearing is immediate -- no further timer advance needed.
    await waitFor(() => expect(getByText('Mogadishu Kitchen')).toBeOnTheScreen());
    expect(queryByText('Kitchen Express')).toBeNull();
  });

  it('shows the unfiltered empty-state copy when there are no restaurants at all', async () => {
    mockHomeRestaurants([]);

    const { getByText } = await renderScreen();

    await waitFor(() => expect(getByText('No restaurants found.')).toBeOnTheScreen());
  });

  it('shows the category-filtered empty-state copy for an empty filtered result set', async () => {
    mockFetchCategories.mockResolvedValue([riceCategory]);
    mockHomeRestaurants([mogadishuKitchen]);
    mockFetchRestaurants.mockImplementation(async (options?: FetchRestaurantsOptions) => {
      if (!options) return [mogadishuKitchen];
      return [];
    });

    const { getByText, getByLabelText } = await renderScreen();
    await waitFor(() => expect(getByText('Mogadishu Kitchen')).toBeOnTheScreen());

    await fireEvent.press(getByLabelText('Rice'));

    await waitFor(() => expect(getByText('No restaurants found in this category.')).toBeOnTheScreen());
  });

  it('shows the search-filtered empty-state copy for an empty search result', async () => {
    mockHomeRestaurants([mogadishuKitchen]);
    mockFetchRestaurants.mockImplementation(async (options?: FetchRestaurantsOptions) => {
      if (!options) return [mogadishuKitchen];
      return [];
    });

    const { getByText, getByPlaceholderText } = await renderScreen();
    await waitFor(() => expect(getByText('Mogadishu Kitchen')).toBeOnTheScreen());

    fireEvent.changeText(getByPlaceholderText('Search restaurants...'), 'sushi');
    await sleep(FOOD_SEARCH_DEBOUNCE_MS + 50);

    await waitFor(() => expect(getByText('No restaurants match "sushi".')).toBeOnTheScreen());
  });

  it('shows the combined category+search empty-state copy when both filters are active', async () => {
    mockFetchCategories.mockResolvedValue([riceCategory]);
    mockHomeRestaurants([mogadishuKitchen]);
    mockFetchRestaurants.mockImplementation(async (options?: FetchRestaurantsOptions) => {
      if (!options) return [mogadishuKitchen];
      return [];
    });

    const { getByText, getByLabelText, getByPlaceholderText } = await renderScreen();
    await waitFor(() => expect(getByText('Mogadishu Kitchen')).toBeOnTheScreen());

    await fireEvent.press(getByLabelText('Rice'));
    await waitFor(() => expect(getByText('No restaurants found in this category.')).toBeOnTheScreen());

    fireEvent.changeText(getByPlaceholderText('Search restaurants...'), 'sushi');
    await sleep(FOOD_SEARCH_DEBOUNCE_MS + 50);

    await waitFor(() => expect(getByText('No restaurants match "sushi" in this category.')).toBeOnTheScreen());
  });

  it('shows an ErrorState with a working retry on a first load that fails', async () => {
    mockFetchCategories.mockRejectedValue(new Error('offline'));
    mockHomeRestaurants([]);

    const { getByTestId, getByText, queryByTestId } = await renderScreen();

    await waitFor(() => expect(getByTestId('error-state')).toBeOnTheScreen());
    expect(getByText('Food options could not be loaded.')).toBeOnTheScreen();

    mockFetchCategories.mockResolvedValue([riceCategory]);

    await fireEvent.press(getByText('Try again'));

    await waitFor(() => expect(queryByTestId('error-state')).toBeNull());
    expect(getByText('Rice')).toBeOnTheScreen();
  });

  it("shows the food cart store's current item count as the cart badge", async () => {
    mockHomeRestaurants([mogadishuKitchen]);
    const burger: CartItem = {
      menuItemId: 'burger-1',
      restaurantId: 'restaurant-1',
      restaurantName: 'Mogadishu Kitchen',
      name: 'Classic Burger',
      unitPrice: 1000,
      imageUrl: '',
      quantity: 2,
    };
    const fries: CartItem = {
      menuItemId: 'fries-1',
      restaurantId: 'restaurant-1',
      restaurantName: 'Mogadishu Kitchen',
      name: 'Side Fries',
      unitPrice: 400,
      imageUrl: '',
      quantity: 3,
    };
    useFoodCartStore.setState({ items: [burger, fries] });

    const { getByText, getByLabelText } = await renderScreen();

    await waitFor(() => expect(getByText('Mogadishu Kitchen')).toBeOnTheScreen());
    expect(getByText('5')).toBeOnTheScreen();
    expect(getByLabelText('Food cart (5)')).toBeOnTheScreen();
  });

  it('shows no cart badge count when the food cart is empty', async () => {
    mockHomeRestaurants([mogadishuKitchen]);

    const { getByText, getByLabelText, queryByText } = await renderScreen();

    await waitFor(() => expect(getByText('Mogadishu Kitchen')).toBeOnTheScreen());
    // The cart action itself is always present (`CartAppBarAction` hides
    // only the numeric badge, not the action chip, at zero) -- mirrors
    // that component's own `itemCount > 0` test coverage.
    expect(getByLabelText('Food cart (0)')).toBeOnTheScreen();
    expect(queryByText('0')).toBeNull();
  });

  it('opens a restaurant route when its row is tapped', async () => {
    mockHomeRestaurants([mogadishuKitchen]);

    const { getByText } = await renderScreen();

    await waitFor(() => expect(getByText('Mogadishu Kitchen')).toBeOnTheScreen());

    await fireEvent.press(getByText('Mogadishu Kitchen'));

    expect(router.push).toHaveBeenCalledWith('/food/restaurants/restaurant-1');
  });

  it('opens the food cart route when the cart action is tapped', async () => {
    mockHomeRestaurants([mogadishuKitchen]);
    useFoodCartStore.setState({
      items: [
        {
          menuItemId: 'burger-1',
          restaurantId: 'restaurant-1',
          restaurantName: 'Mogadishu Kitchen',
          name: 'Classic Burger',
          unitPrice: 1000,
          imageUrl: '',
          quantity: 1,
        },
      ],
    });

    const { getByText, getByLabelText } = await renderScreen();

    await waitFor(() => expect(getByText('Mogadishu Kitchen')).toBeOnTheScreen());

    await fireEvent.press(getByLabelText('Food cart (1)'));

    expect(router.push).toHaveBeenCalledWith(AppRoutes.foodCart);
  });
});
