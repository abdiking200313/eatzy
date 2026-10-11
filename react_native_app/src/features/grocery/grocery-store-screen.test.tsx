/**
 * Ports the store-screen cases from `flutter_app/test/grocery_screens_test.dart`
 * (issue #390 / P7-02): "tapping a store opens a catalog scoped to just that
 * store, searchable by product name". The `groupByCategory` case is ported
 * in `grocery-catalog.test.ts`.
 *
 * "tapping a product opens its details page, which adds the picked weight
 * to the cart" is ported only up to the navigation half here (the product
 * is pushed to the right per-store-type details route) -- the details
 * screen half is ported in `grocery-product-details-screen.test.tsx`
 * (issue #391). The rest of this file covers the Dart screen's own behavior that
 * the Dart test file never asserts directly: category sections, empty/
 * not-found/error states, the add-to-cart snackbar copy, and the
 * one-store-per-cart conflict prompt.
 *
 * `@/platform/supabase/client` is mocked for the same reason as
 * `grocery-store-list-screen.test.tsx`; `expo-router` is mocked the same way
 * the restaurant screen test mocks it.
 */
import { act, fireEvent, waitFor } from '@testing-library/react-native';
import { router } from 'expo-router';
import { Alert } from 'react-native';

import { groceryCartStores, type GroceryProduct } from '@/stores/grocery-cart-store';
import { renderWithProviders } from '@/test-utils';

import type { GroceryStore } from './api/grocery-store';
import { GroceryStoreScreen } from './grocery-store-screen';

jest.mock('expo-router', () => ({
  router: {
    push: jest.fn(),
    canGoBack: jest.fn(() => false),
    back: jest.fn(),
    replace: jest.fn(),
  },
}));

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

function product(overrides: Partial<GroceryProduct> & Pick<GroceryProduct, 'id' | 'name'>): GroceryProduct {
  return {
    storeId: 'bakaal-fresh',
    description: '',
    unitPrice: 100,
    pricingUnit: 'each',
    stockState: 'inStock',
    availableQuantity: 10,
    icon: '🛒',
    imageUrl: null,
    categoryName: null,
    categorySortOrder: 0,
    ...overrides,
  };
}

// Mirrors `SeededGroceryRepository`'s Bakaal Fresh store.
const bananas = product({
  id: 'bakaal-bananas',
  name: 'Bananas',
  description: 'Fresh bananas, sold by weight',
  unitPrice: 180,
  pricingUnit: 'kilogram',
  availableQuantity: 12,
  icon: '🍌',
});
const rice = product({ id: 'bakaal-rice', name: 'Basmati rice', description: 'One 5 kg bag', unitPrice: 850, availableQuantity: 24 });

const bakaalFresh: GroceryStore = {
  id: 'bakaal-fresh',
  name: 'Bakaal Fresh',
  area: 'Hodan, Mogadishu',
  imageUrl: null,
  storeType: 'grocery',
  products: [bananas, rice],
};

function loaderFor(store: GroceryStore | null) {
  return jest.fn(async () => store);
}

beforeEach(() => {
  jest.clearAllMocks();
  for (const handle of Object.values(groceryCartStores)) {
    handle.store.getState().clearInMemory();
  }
});

describe('GroceryStoreScreen', () => {
  it('shows a catalog scoped to just that store, searchable by product name', async () => {
    const loader = loaderFor(bakaalFresh);
    const { getByText, queryByText, getByPlaceholderText } = await renderWithProviders(
      <GroceryStoreScreen storeId="bakaal-fresh" storeLoader={loader} />,
    );

    await waitFor(() => expect(getByText('Bananas')).toBeOnTheScreen());
    expect(loader).toHaveBeenCalledWith('bakaal-fresh');
    expect(getByText('Bakaal Fresh')).toBeOnTheScreen();
    expect(getByText('Hodan, Mogadishu')).toBeOnTheScreen();
    expect(getByText('Basmati rice')).toBeOnTheScreen();
    expect(getByText('$1.80 per kg')).toBeOnTheScreen();
    expect(getByText('$8.50 each')).toBeOnTheScreen();

    await fireEvent.changeText(getByPlaceholderText('Search products...'), 'rice');

    await waitFor(() => expect(queryByText('Bananas')).toBeNull());
    expect(getByText('Basmati rice')).toBeOnTheScreen();

    await fireEvent.changeText(getByPlaceholderText('Search products...'), 'milk');
    await waitFor(() => expect(getByText('No products match "milk".')).toBeOnTheScreen());
  });

  it('groups products into category sections ordered by sort order, with item counts and "Other" last', async () => {
    const store: GroceryStore = {
      ...bakaalFresh,
      products: [
        product({ id: 'bread', name: 'Bread', categoryName: 'Bread & bakery', categorySortOrder: 5 }),
        product({ id: 'box', name: 'Mystery box' }),
        product({ id: 'apples', name: 'Apples', categoryName: 'Fruits & vegetables', categorySortOrder: 1 }),
        product({ id: 'baguette', name: 'Baguette', categoryName: 'Bread & bakery', categorySortOrder: 5 }),
      ],
    };
    const { getByText, getByTestId, getAllByTestId, queryByTestId, getByPlaceholderText } = await renderWithProviders(
      <GroceryStoreScreen storeId="bakaal-fresh" storeLoader={loaderFor(store)} />,
    );

    await waitFor(() => expect(getByText('Fruits & vegetables')).toBeOnTheScreen());
    expect(getByText('2 items')).toBeOnTheScreen();
    expect(getByTestId('grocery-category-Other')).toBeOnTheScreen();

    // The catalog is a FlashList (issue #417), whose host element carries no
    // `data` prop -- read the order off the rendered section headers instead.
    const headerOrder = getAllByTestId(/^grocery-category-/).map((header) =>
      String(header.props.testID).replace('grocery-category-', ''),
    );
    expect(headerOrder).toEqual(['Fruits & vegetables', 'Bread & bakery', 'Other']);

    // A search that only matches one category drops the lone section's header.
    await fireEvent.changeText(getByPlaceholderText('Search products...'), 'bread');
    await waitFor(() => expect(queryByTestId('grocery-category-Bread & bakery')).toBeNull());
    expect(getByText('Bread')).toBeOnTheScreen();
  });

  it('tapping a product pushes its per-store-type details route', async () => {
    const { getByText } = await renderWithProviders(
      <GroceryStoreScreen storeId="bakaal-fresh" storeLoader={loaderFor(bakaalFresh)} />,
    );
    await waitFor(() => expect(getByText('Bananas')).toBeOnTheScreen());

    await fireEvent.press(getByText('Bananas'));
    expect(router.push).toHaveBeenCalledWith('/grocery/stores/bakaal-fresh/product/bakaal-bananas');
  });

  it('a Fresh Meat store adds to the Fresh Meat cart and links to Fresh Meat routes', async () => {
    const goat = product({ id: 'goat', storeId: 'butcher', name: 'Goat', pricingUnit: 'kilogram', availableQuantity: 5 });
    const butcher: GroceryStore = { id: 'butcher', name: 'Hamar Meat', area: 'Hamar', imageUrl: null, storeType: 'fresh_meat', products: [goat] };
    const { getByText, getByLabelText } = await renderWithProviders(
      <GroceryStoreScreen storeId="butcher" storeType="fresh_meat" storeLoader={loaderFor(butcher)} />,
    );
    await waitFor(() => expect(getByText('Goat')).toBeOnTheScreen());

    await fireEvent.press(getByLabelText('Add Goat'));
    expect(groceryCartStores.fresh_meat.store.getState().lines).toEqual([{ product: goat, quantity: 0.5 }]);
    expect(groceryCartStores.grocery.store.getState().lines).toEqual([]);
    await waitFor(() => expect(getByText('Goat added to your grocery cart.')).toBeOnTheScreen());

    await fireEvent.press(getByLabelText('Fresh Meat cart (1)'));
    expect(router.push).toHaveBeenCalledWith('/grocery/fresh-meat/cart');

    await fireEvent.press(getByText('Goat'));
    expect(router.push).toHaveBeenCalledWith('/grocery/fresh-meat/stores/butcher/product/goat');
  });

  it('adding shows the matching snackbar copy, and an out-of-stock product cannot be added', async () => {
    const soldOut = product({ id: 'eggs', name: 'Eggs', stockState: 'outOfStock', availableQuantity: 0 });
    const { getByText, getByLabelText } = await renderWithProviders(
      <GroceryStoreScreen storeId="bakaal-fresh" storeLoader={loaderFor({ ...bakaalFresh, products: [rice, soldOut] })} />,
    );
    await waitFor(() => expect(getByText('Basmati rice')).toBeOnTheScreen());

    await fireEvent.press(getByLabelText('Add Basmati rice'));
    await waitFor(() => expect(getByText('Basmati rice added to your grocery cart.')).toBeOnTheScreen());
    await fireEvent.press(getByLabelText('Add Basmati rice'));
    await waitFor(() => expect(getByText('Basmati rice quantity increased.')).toBeOnTheScreen());
    expect(groceryCartStores.grocery.store.getState().lines[0].quantity).toBe(2);

    // Disabled add button carries the stock label as its tooltip.
    const soldOutButton = getByLabelText('Out of stock');
    expect(soldOutButton.props.accessibilityState).toEqual({ disabled: true });
  });

  it('adding from a different store prompts to replace the cart, and keeps it on "Keep current cart"', async () => {
    const otherStoreItem = product({ id: 'potatoes', storeId: 'suuqa-hamar', name: 'Potatoes' });
    groceryCartStores.grocery.store.getState().addProduct(otherStoreItem);
    const alertSpy = jest.spyOn(Alert, 'alert').mockImplementation(() => {});

    const { getByText, getByLabelText } = await renderWithProviders(
      <GroceryStoreScreen storeId="bakaal-fresh" storeLoader={loaderFor(bakaalFresh)} />,
    );
    await waitFor(() => expect(getByText('Basmati rice')).toBeOnTheScreen());

    await fireEvent.press(getByLabelText('Add Basmati rice'));

    expect(alertSpy).toHaveBeenCalledTimes(1);
    const [title, message, buttons] = alertSpy.mock.calls[0];
    expect(title).toBe('Start a new store cart?');
    expect(message).toBe('The grocery MVP keeps one store per checkout. Your current grocery cart will be replaced.');
    expect(buttons?.map((b) => b.text)).toEqual(['Keep current cart', 'Replace cart']);

    await act(async () => buttons![0].onPress!());
    expect(groceryCartStores.grocery.store.getState().lines.map((l) => l.product.id)).toEqual(['potatoes']);
    await waitFor(() => expect(getByText('Your current grocery cart was kept.')).toBeOnTheScreen());

    await act(async () => buttons![1].onPress!());
    expect(groceryCartStores.grocery.store.getState().lines.map((l) => l.product.id)).toEqual(['bakaal-rice']);
    await waitFor(() => expect(getByText('Basmati rice added to your grocery cart.')).toBeOnTheScreen());

    alertSpy.mockRestore();
  });

  it('shows the empty-catalog message for a store with no products', async () => {
    const { getByText } = await renderWithProviders(
      <GroceryStoreScreen storeId="bakaal-fresh" storeLoader={loaderFor({ ...bakaalFresh, products: [] })} />,
    );
    await waitFor(() => expect(getByText('This store has no products yet.')).toBeOnTheScreen());
  });

  it('shows "not found" under the plain Store title when the store does not exist', async () => {
    const { getByText } = await renderWithProviders(<GroceryStoreScreen storeId="missing" storeLoader={loaderFor(null)} />);
    await waitFor(() => expect(getByText('This store could not be found.')).toBeOnTheScreen());
    expect(getByText('Store')).toBeOnTheScreen();
  });

  it('shows an error with a working retry when the store fails to load', async () => {
    const loader = jest
      .fn<Promise<GroceryStore | null>, [string]>()
      .mockRejectedValueOnce(new Error('offline'))
      .mockResolvedValueOnce(bakaalFresh);
    const { getByText } = await renderWithProviders(<GroceryStoreScreen storeId="bakaal-fresh" storeLoader={loader} />);

    await waitFor(() => expect(getByText('This store could not be loaded. Please try again.')).toBeOnTheScreen());
    await fireEvent.press(getByText('Try again'));

    await waitFor(() => expect(getByText('Bananas')).toBeOnTheScreen());
    expect(loader).toHaveBeenCalledTimes(2);
  });

  it('pulling to refresh reloads the store, keeping it on screen if the refresh fails', async () => {
    const loader = jest
      .fn<Promise<GroceryStore | null>, [string]>()
      .mockResolvedValueOnce(bakaalFresh)
      .mockRejectedValueOnce(new Error('offline'));
    const { getByText, getByTestId } = await renderWithProviders(<GroceryStoreScreen storeId="bakaal-fresh" storeLoader={loader} />);
    await waitFor(() => expect(getByText('Bananas')).toBeOnTheScreen());

    await act(async () => {
      await getByTestId('grocery-store-catalog').props.refreshControl.props.onRefresh();
    });

    expect(loader).toHaveBeenCalledTimes(2);
    expect(getByText('Bananas')).toBeOnTheScreen();
  });
});
