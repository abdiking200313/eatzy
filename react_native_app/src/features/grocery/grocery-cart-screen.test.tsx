/**
 * Covers `GroceryCartScreen` (issue #392 / P7-04). Flutter has no dedicated
 * test for `grocery_cart_screen.dart`; these assert the Dart screen's own
 * behavior directly: per-store-type title/empty copy, the store name, line
 * labels (weighed vs. counted), subtotal + delivery fee, the "No more X is
 * available." snack bar at the stock limit, stepping down to removal, and
 * navigation to checkout / back to the store list.
 */
import { QueryClient } from '@tanstack/react-query';
import { fireEvent, waitFor } from '@testing-library/react-native';
import { router } from 'expo-router';

import { AppRoutes } from '@/platform/navigation/app-routes';
import type { ServicePricing } from '@/platform/pricing/service-pricing-repository';
import { groceryCartStores, type GroceryCartLine, type GroceryProduct, type GroceryStoreType } from '@/stores/grocery-cart-store';
import { createTestQueryClient, renderWithProviders } from '@/test-utils';

import type { GroceryStore } from './api/grocery-store';
import { GroceryCartScreen } from './grocery-cart-screen';

jest.mock('expo-router', () => ({
  router: { push: jest.fn(), canGoBack: jest.fn(() => true), back: jest.fn(), replace: jest.fn() },
}));

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

const rice: GroceryProduct = {
  id: 'bakaal-rice',
  storeId: 'bakaal-fresh',
  name: 'Basmati rice',
  description: 'One 5 kg bag',
  unitPrice: 850,
  pricingUnit: 'each',
  stockState: 'inStock',
  availableQuantity: 2,
  icon: '🛒',
};
const bananas: GroceryProduct = { ...rice, id: 'bakaal-bananas', name: 'Bananas', unitPrice: 180, pricingUnit: 'kilogram', availableQuantity: 12 };

const bakaalFresh: GroceryStore = {
  id: 'bakaal-fresh',
  name: 'Bakaal Fresh',
  area: 'Hodan',
  imageUrl: null,
  storeType: 'grocery',
  products: [rice, bananas],
};

const pricing: ServicePricing = { serviceId: 'grocery', deliveryFeeCents: 250, taxRate: 0 };
const renderedQueryClients: QueryClient[] = [];

async function renderScreen({
  storeType = 'grocery' as GroceryStoreType,
  lines = [
    { product: rice, quantity: 2 },
    { product: bananas, quantity: 1.5 },
  ] as GroceryCartLine[],
  withPricing = true,
} = {}) {
  groceryCartStores[storeType].store.setState({ lines, ownerId: 'user-1', isLoading: false });
  const queryClient = createTestQueryClient();
  if (withPricing) queryClient.setQueryData(['service-pricing', 'grocery'], pricing);
  renderedQueryClients.push(queryClient);
  const storeLoader = jest.fn(async () => bakaalFresh);
  const view = await renderWithProviders(<GroceryCartScreen storeType={storeType} storeLoader={storeLoader} />, { queryClient });
  return { ...view, storeLoader };
}

afterEach(() => {
  jest.clearAllMocks();
  for (const handle of Object.values(groceryCartStores)) {
    handle.store.setState({ lines: [], ownerId: null, isLoading: false });
  }
  renderedQueryClients.splice(0).forEach((client) => client.clear());
});

describe('GroceryCartScreen', () => {
  it('shows the store, each line, subtotal and delivery fee, and continues to checkout', async () => {
    const { getByText, findByText, getByTestId, storeLoader } = await renderScreen();

    expect(getByText('Grocery cart')).toBeOnTheScreen();
    expect(await findByText('Bakaal Fresh')).toBeOnTheScreen();
    expect(storeLoader).toHaveBeenCalledWith('bakaal-fresh');
    expect(getByText('Basmati rice')).toBeOnTheScreen();
    expect(getByText('Bananas')).toBeOnTheScreen();
    // 2 × $8.50 + 1.5 kg × $1.80 = $19.70, plus a $2.50 delivery fee.
    expect(getByText('$19.70')).toBeOnTheScreen();
    expect(getByText('$2.50')).toBeOnTheScreen();

    await fireEvent.press(getByTestId('cart-checkout'));
    expect(router.push).toHaveBeenCalledWith(AppRoutes.groceryCheckout);
  });

  it('shows the delivery fee as pending until pricing loads', async () => {
    const { getAllByText } = await renderScreen({ withPricing: false });

    expect(getAllByText('Calculated at checkout').length).toBeGreaterThan(0);
  });

  it('says no more is available at the stock limit, and steps down to removal', async () => {
    const { getAllByLabelText, findByText } = await renderScreen({ lines: [{ product: rice, quantity: 2 }] });

    await fireEvent.press(getAllByLabelText(/increase/i)[0]);
    expect(await findByText('No more Basmati rice is available.')).toBeOnTheScreen();
    expect(groceryCartStores.grocery.store.getState().lines[0].quantity).toBe(2);

    await fireEvent.press(getAllByLabelText(/decrease/i)[0]);
    await fireEvent.press(getAllByLabelText(/decrease/i)[0]);
    await waitFor(() => expect(groceryCartStores.grocery.store.getState().lines).toEqual([]));
  });

  it('uses each store type’s own cart, copy and routes', async () => {
    const { getByText } = await renderScreen({ storeType: 'electronics', lines: [] });

    expect(getByText('Electronics cart')).toBeOnTheScreen();
    expect(getByText('Your electronics cart is empty')).toBeOnTheScreen();
    await fireEvent.press(getByText('Browse stores'));
    expect(router.replace).toHaveBeenCalledWith(AppRoutes.electronics);
  });
});
