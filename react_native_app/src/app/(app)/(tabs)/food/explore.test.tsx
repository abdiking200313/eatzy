/**
 * Ports `flutter_app/test/food_explore_screen_test.dart` against the real
 * `FoodExploreScreen` (issue #385), plus loading/error/search/navigation
 * cases covering the rest of the Dart screen's behavior.
 *
 * Not ported: "food Explore stays overflow-free on a narrow, large-text
 * screen" -- a Flutter `RenderFlex` overflow assertion
 * (`tester.takeException()` at 320px / 1.4x text) with no React Native
 * equivalent, same precedent as `index.test.tsx`/`../explore.test.tsx`.
 *
 * Seams: `restaurant-repository.ts`'s `fetchRestaurants` is mocked in
 * place of the Dart test's `_FakeRestaurantRepository`/`restaurants`
 * future (its recorded call args stand in for `capturedCategoryId`), and
 * `expo-router`'s `useLocalSearchParams` is mocked in place of the Dart
 * test passing `categoryId`/`categoryName` constructor params (which
 * `app_router.dart` reads from the same query params).
 */
import { QueryClient } from '@tanstack/react-query';
import { fireEvent, waitFor } from '@testing-library/react-native';
import { router, useLocalSearchParams } from 'expo-router';

import { renderWithProviders } from '@/test-utils';
import { fetchRestaurants } from '@/features/food/api/restaurant-repository';
import type { Restaurant } from '@/features/food/api/restaurant';

import FoodExploreScreen from './explore';

jest.mock('expo-router', () => ({
  router: { push: jest.fn(), canGoBack: jest.fn(() => false), back: jest.fn() },
  useLocalSearchParams: jest.fn(() => ({})),
}));

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

jest.mock('@/features/food/api/restaurant-repository', () => ({
  fetchRestaurants: jest.fn(),
}));

const mockFetchRestaurants = fetchRestaurants as jest.Mock;
const mockUseLocalSearchParams = useLocalSearchParams as jest.Mock;

const mogadishuKitchen: Restaurant = {
  id: 'restaurant-1',
  name: 'Mogadishu Kitchen',
  description: 'Somali favourites',
  logoUrl: '',
};
const riceBowl: Restaurant = { id: 'restaurant-2', name: 'Rice Bowl', description: 'Rice specialists', logoUrl: '' };

const renderedQueryClients: QueryClient[] = [];

async function renderScreen() {
  const result = await renderWithProviders(<FoodExploreScreen />);
  renderedQueryClients.push(result.queryClient);
  return result;
}

beforeEach(() => {
  mockFetchRestaurants.mockReset().mockResolvedValue([]);
  mockUseLocalSearchParams.mockReset().mockReturnValue({});
  (router.push as jest.Mock).mockClear();
});

afterEach(() => {
  renderedQueryClients.splice(0).forEach((client) => client.clear());
});

describe('FoodExploreScreen', () => {
  it('food Explore lists restaurants rather than service modules', async () => {
    mockFetchRestaurants.mockResolvedValue([mogadishuKitchen]);

    const { findByText, getByText, queryByText } = await renderScreen();

    expect(await findByText('Mogadishu Kitchen')).toBeOnTheScreen();
    expect(getByText('Explore restaurants')).toBeOnTheScreen();
    expect(queryByText('Grocery')).toBeNull();
    expect(queryByText('Pharmacy')).toBeNull();
    // Unscoped: no category filter is passed to the repository.
    expect(mockFetchRestaurants).toHaveBeenCalledWith({});
  });

  it('a category-scoped explore view titles itself and filters via the repository', async () => {
    mockUseLocalSearchParams.mockReturnValue({ categoryId: 'rice', categoryName: 'Rice dishes' });
    mockFetchRestaurants.mockResolvedValue([riceBowl]);

    const { findByText, getByText, queryByText } = await renderScreen();

    expect(await findByText('Rice Bowl')).toBeOnTheScreen();
    expect(getByText('Rice dishes')).toBeOnTheScreen();
    expect(queryByText('Explore restaurants')).toBeNull();
    expect(mockFetchRestaurants).toHaveBeenCalledWith({ categoryId: 'rice' });
  });

  it('an empty category result shows a category-aware empty state', async () => {
    mockUseLocalSearchParams.mockReturnValue({ categoryId: 'rice', categoryName: 'Rice dishes' });

    const { findByText } = await renderScreen();

    expect(await findByText('No restaurants found in this category.')).toBeOnTheScreen();
  });

  it('an empty unscoped result shows the generic empty state', async () => {
    const { findByText } = await renderScreen();

    expect(await findByText('No restaurants are available yet.')).toBeOnTheScreen();
  });

  it('shows a loading state, then the list', async () => {
    let resolveRestaurants!: (value: Restaurant[]) => void;
    mockFetchRestaurants.mockReturnValue(new Promise<Restaurant[]>((resolve) => (resolveRestaurants = resolve)));

    const { getByTestId, getByText, queryByTestId } = await renderScreen();
    expect(getByTestId('loading-state')).toBeOnTheScreen();

    resolveRestaurants([mogadishuKitchen]);
    await waitFor(() => expect(queryByTestId('loading-state')).toBeNull());
    expect(getByText('Mogadishu Kitchen')).toBeOnTheScreen();
  });

  it('shows an error state when restaurants fail to load, and retries', async () => {
    mockFetchRestaurants.mockRejectedValueOnce(new Error('boom')).mockResolvedValue([mogadishuKitchen]);

    const { findByText, getByText } = await renderScreen();

    expect(await findByText('Restaurants could not be loaded.')).toBeOnTheScreen();
    await fireEvent.press(getByText('Try again'));
    await waitFor(() => expect(getByText('Mogadishu Kitchen')).toBeOnTheScreen());
  });

  it('the search box filters the loaded list by name, client-side', async () => {
    mockFetchRestaurants.mockResolvedValue([mogadishuKitchen, riceBowl]);

    const { findByText, getByPlaceholderText, getByText, queryByText } = await renderScreen();
    await findByText('Mogadishu Kitchen');

    await fireEvent.changeText(getByPlaceholderText('Search restaurants...'), '  rice ');
    expect(getByText('Rice Bowl')).toBeOnTheScreen();
    expect(queryByText('Mogadishu Kitchen')).toBeNull();

    await fireEvent.changeText(getByPlaceholderText('Search restaurants...'), 'pizza');
    expect(getByText('No restaurants match "pizza".')).toBeOnTheScreen();

    // Filtering never refetches -- mirrors Dart's `_visibleRestaurants`.
    expect(mockFetchRestaurants).toHaveBeenCalledTimes(1);
  });

  it('tapping a restaurant opens its menu', async () => {
    mockFetchRestaurants.mockResolvedValue([mogadishuKitchen]);

    const { findByText } = await renderScreen();
    await fireEvent.press(await findByText('Mogadishu Kitchen'));

    expect(router.push).toHaveBeenCalledWith('/food/restaurants/restaurant-1');
  });
});
