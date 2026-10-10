/**
 * Ports `flutter_app/test/food_categories_screen_test.dart` against the
 * real `FoodCategoriesScreen` (issue #385), plus loading/empty/error cases
 * covering the Dart screen's `FutureBuilder` branches.
 *
 * Not ported: "food categories stays overflow-free on a narrow,
 * large-text screen" -- a Flutter `RenderFlex` overflow assertion
 * (`tester.takeException()` at 320px / 1.4x text) with no React Native
 * equivalent, same precedent as `index.test.tsx`/`../explore.test.tsx`.
 *
 * Seams: as in `index.test.tsx`, the repository module
 * (`category-repository.ts`) is mocked in place of the Dart test's injected
 * `categories` future, `expo-router`'s imperative `router` is mocked so
 * the navigation case asserts the pushed location (the Dart test's stub
 * `/food/explore` route echoing its query params), and
 * `@/platform/supabase/client` is stubbed since it reads env vars at
 * import time.
 */
import { QueryClient } from '@tanstack/react-query';
import { fireEvent, waitFor } from '@testing-library/react-native';
import { router } from 'expo-router';

import { renderWithProviders } from '@/test-utils';
import { fetchCategories } from '@/features/food/api/category-repository';
import type { Category } from '@/features/food/api/category';

import FoodCategoriesScreen from './categories';

jest.mock('expo-router', () => ({
  router: { push: jest.fn(), canGoBack: jest.fn(() => false), back: jest.fn() },
}));

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

jest.mock('@/features/food/api/category-repository', () => ({
  fetchCategories: jest.fn(),
}));

const mockFetchCategories = fetchCategories as jest.Mock;

const categories: Category[] = [
  { id: 'rice', name: 'Rice dishes', iconUrl: '' },
  { id: 'grill', name: 'Grilled favourites', iconUrl: '' },
];

const renderedQueryClients: QueryClient[] = [];

async function renderScreen() {
  const result = await renderWithProviders(<FoodCategoriesScreen />);
  renderedQueryClients.push(result.queryClient);
  return result;
}

beforeEach(() => {
  mockFetchCategories.mockReset().mockResolvedValue(categories);
  (router.push as jest.Mock).mockClear();
});

afterEach(() => {
  renderedQueryClients.splice(0).forEach((client) => client.clear());
});

describe('FoodCategoriesScreen', () => {
  it('food categories renders a white-card grid of categories', async () => {
    const { getByText, getByTestId } = await renderScreen();

    await waitFor(() => expect(getByText('Rice dishes')).toBeOnTheScreen());
    expect(getByText('Grilled favourites')).toBeOnTheScreen();
    expect(getByText('Food categories')).toBeOnTheScreen();
    expect(getByTestId('food-category-card-rice')).toBeOnTheScreen();
    expect(getByTestId('food-category-card-grill')).toBeOnTheScreen();
  });

  it('tapping a category card navigates to a filtered explore view', async () => {
    const { getByText } = await renderScreen();

    await waitFor(() => expect(getByText('Rice dishes')).toBeOnTheScreen());
    await fireEvent.press(getByText('Rice dishes'));

    expect(router.push).toHaveBeenCalledTimes(1);
    const pushed = (router.push as jest.Mock).mock.calls[0][0] as string;
    expect(pushed).toBe('/food/explore?categoryId=rice&categoryName=Rice%20dishes');
    // Same assertion shape as the Dart test's echoing stub route.
    const query = new URL(pushed, 'https://zivo.test').searchParams;
    expect(`categoryId=${query.get('categoryId')} categoryName=${query.get('categoryName')}`).toBe(
      'categoryId=rice categoryName=Rice dishes',
    );
  });

  it('shows a loading state until categories have loaded', async () => {
    let resolveCategories!: (value: Category[]) => void;
    mockFetchCategories.mockReturnValue(new Promise<Category[]>((resolve) => (resolveCategories = resolve)));

    const { getByTestId, getByText, queryByTestId } = await renderScreen();
    expect(getByTestId('loading-state')).toBeOnTheScreen();

    resolveCategories(categories);
    await waitFor(() => expect(queryByTestId('loading-state')).toBeNull());
    expect(getByText('Rice dishes')).toBeOnTheScreen();
  });

  it('shows an empty state when there are no categories', async () => {
    mockFetchCategories.mockResolvedValue([]);

    const { findByText } = await renderScreen();

    expect(await findByText('No food categories are available yet.')).toBeOnTheScreen();
  });

  it('shows an error state when categories fail to load, and retries', async () => {
    mockFetchCategories.mockRejectedValueOnce(new Error('boom'));

    const { findByText, getByText } = await renderScreen();

    expect(await findByText('Food categories could not be loaded.')).toBeOnTheScreen();

    await fireEvent.press(getByText('Try again'));
    await waitFor(() => expect(getByText('Rice dishes')).toBeOnTheScreen());
    expect(mockFetchCategories).toHaveBeenCalledTimes(2);
  });
});
