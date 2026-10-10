/**
 * Ports the store-list cases from `flutter_app/test/grocery_screens_test.dart`
 * and `flutter_app/test/grocery_store_type_test.dart` (issue #389 / P7-01).
 * Not ported: tapping a store's full catalog/product-details behavior --
 * that belongs to the store-scoped catalog screen landing in a later issue
 * (#391); this screen's own job stops at rendering the store list and
 * navigating to a store's details route.
 *
 * `@/platform/supabase/client` is mocked the same way `explore.test.tsx`
 * mocks it -- `grocery-repository.ts`'s default parameter imports it at
 * module load time, even though every test here injects its own
 * `storesLoader` and never actually calls the default.
 */
import { act, fireEvent, waitFor } from '@testing-library/react-native';
import { router } from 'expo-router';

import { renderWithProviders } from '@/test-utils';

import type { GroceryStore } from './api/grocery-store';
import { GroceryStoreListScreen } from './grocery-store-list-screen';

jest.mock('expo-router', () => ({
  router: {
    push: jest.fn(),
  },
}));

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

function store(overrides: Partial<GroceryStore> & Pick<GroceryStore, 'id' | 'name' | 'area'>): GroceryStore {
  return { imageUrl: null, storeType: 'grocery', products: [], ...overrides };
}

const bakaalFresh = store({
  id: 'bakaal-fresh',
  name: 'Bakaal Fresh',
  area: 'Hodan, Mogadishu',
  products: [{}] as unknown as GroceryStore['products'],
});
const suuqaHamar = store({ id: 'suuqa-hamar', name: 'Suuqa Hamar', area: 'Waberi, Mogadishu' });
const hamarMeat = store({ id: 'butcher', name: 'Hamar Meat', area: 'Hamar', storeType: 'fresh_meat' });
const phoneHub = store({ id: 'phones', name: 'Phone Hub', area: 'KM4', storeType: 'electronics' });

const mixedStores = [bakaalFresh, suuqaHamar, hamarMeat, phoneHub];

beforeEach(() => {
  (router.push as jest.Mock).mockClear();
});

describe('GroceryStoreListScreen', () => {
  it('renders every seeded store by name for its own store type, and searching filters by name', async () => {
    const { getByText, queryByText, getByPlaceholderText } = await renderWithProviders(
      <GroceryStoreListScreen storeType="grocery" storesLoader={async () => mixedStores} />,
    );

    await waitFor(() => expect(getByText('Bakaal Fresh')).toBeOnTheScreen());
    expect(getByText('Suuqa Hamar')).toBeOnTheScreen();
    // Only this store type's stores show -- Fresh Meat/Electronics stores are excluded.
    expect(queryByText('Hamar Meat')).toBeNull();
    expect(queryByText('Phone Hub')).toBeNull();

    await fireEvent.changeText(getByPlaceholderText('Search stores...'), 'hamar');

    await waitFor(() => expect(queryByText('Bakaal Fresh')).toBeNull());
    expect(getByText('Suuqa Hamar')).toBeOnTheScreen();
  });

  it('each store type only lists its own stores', async () => {
    for (const [storeType, expectedId] of [
      ['grocery', 'bakaal-fresh'],
      ['fresh_meat', 'butcher'],
      ['electronics', 'phones'],
    ] as const) {
      const { getByText } = await renderWithProviders(
        <GroceryStoreListScreen storeType={storeType} storesLoader={async () => mixedStores} />,
      );
      await waitFor(() => expect(getByText(mixedStores.find((s) => s.id === expectedId)!.name)).toBeOnTheScreen());
    }
  });

  it('shows the product count as a trailing caption', async () => {
    const { getByText } = await renderWithProviders(<GroceryStoreListScreen storeType="grocery" storesLoader={async () => mixedStores} />);

    await waitFor(() => expect(getByText('1 product')).toBeOnTheScreen());
    expect(getByText('0 products')).toBeOnTheScreen();
  });

  it('tapping a store navigates to its details route', async () => {
    const { getByText } = await renderWithProviders(<GroceryStoreListScreen storeType="fresh_meat" storesLoader={async () => mixedStores} />);

    await waitFor(() => expect(getByText('Hamar Meat')).toBeOnTheScreen());
    await fireEvent.press(getByText('Hamar Meat'));

    expect(router.push).toHaveBeenCalledWith('/grocery/fresh-meat/stores/butcher');
  });

  it('pulling to refresh reloads the store list', async () => {
    let fetchCount = 0;
    const loader = async () => {
      fetchCount += 1;
      return mixedStores;
    };

    const { getByText, getByTestId } = await renderWithProviders(<GroceryStoreListScreen storeType="grocery" storesLoader={loader} />);

    await waitFor(() => expect(getByText('Bakaal Fresh')).toBeOnTheScreen());
    expect(fetchCount).toBe(1);

    await act(async () => {
      await getByTestId('grocery-store-list').props.refreshControl.props.onRefresh();
    });

    expect(fetchCount).toBe(2);
  });

  it('shows an error message with a retry action when the store list fails to load', async () => {
    const { getByText } = await renderWithProviders(
      <GroceryStoreListScreen storeType="grocery" storesLoader={async () => Promise.reject(new Error('offline'))} />,
    );

    await waitFor(() => expect(getByText('Groceries could not be loaded. Please try again.')).toBeOnTheScreen());
    expect(getByText('Try again')).toBeOnTheScreen();
  });
});
