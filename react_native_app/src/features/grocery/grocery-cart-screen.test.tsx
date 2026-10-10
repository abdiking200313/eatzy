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

  // Ports cart_screens_test.dart's grocery "renders lines with totals, and
  // increase/decrease updates the line total and the cart subtotal" (issue
  // #396 parity).
  it('increase/decrease updates the line total and the cart subtotal', async () => {
    const { getByText, getAllByText, getByLabelText } = await renderScreen({
      lines: [
        { product: rice, quantity: 1 },
        { product: bananas, quantity: 1.5 },
      ],
    });
    const riceQuantity = () => groceryCartStores.grocery.store.getState().lines.find((line) => line.product.id === 'bakaal-rice')!.quantity;

    // $8.50 + 1.5 kg × $1.80 = $11.20, plus a $2.50 delivery fee = $13.70.
    expect(getAllByText('$8.50').length).toBeGreaterThan(0);
    expect(getByText('$11.20')).toBeOnTheScreen();
    expect(getAllByText('$13.70').length).toBeGreaterThan(0);

    await fireEvent.press(getByLabelText('Increase Basmati rice'));
    expect(riceQuantity()).toBe(2);
    expect(getByText('$17.00')).toBeOnTheScreen();
    expect(getByText('$19.70')).toBeOnTheScreen();
    expect(getAllByText('$22.20').length).toBeGreaterThan(0);

    await fireEvent.press(getByLabelText('Decrease Basmati rice'));
    expect(riceQuantity()).toBe(1);
    expect(getByText('$11.20')).toBeOnTheScreen();
    expect(getAllByText('$13.70').length).toBeGreaterThan(0);
  });

  // Ports cart_screens_test.dart's grocery "removing the only line in the
  // cart shows the empty state" (issue #396 parity).
  it('removing the only line in the cart shows the empty state', async () => {
    const { getByTestId, findByText } = await renderScreen({ lines: [{ product: rice, quantity: 1 }] });

    await fireEvent.press(getByTestId('remove-cart-item-bakaal-rice'));

    expect(await findByText('Your grocery cart is empty')).toBeOnTheScreen();
    expect(groceryCartStores.grocery.store.getState().lines).toEqual([]);
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

  // Matches grocery_store_type_test.dart's "the Fresh Meat cart is titled
  // and linked as Fresh Meat" (issue #393), plus the Electronics sibling.
  // The grocery row also ports cart_screens_test.dart's shared "grocery: an
  // empty cart has no checkout button, and "Browse stores" navigates back to
  // the catalog" (issue #396 parity).
  it.each([
    ['grocery', 'Grocery cart', 'Your grocery cart is empty', AppRoutes.grocery],
    ['fresh_meat', 'Fresh Meat cart', 'Your fresh meat cart is empty', AppRoutes.freshMeat],
    ['electronics', 'Electronics cart', 'Your electronics cart is empty', AppRoutes.electronics],
  ] as const)('uses the %s store type’s own cart, copy and routes', async (storeType, title, empty, listRoute) => {
    const { getByText, queryByTestId } = await renderScreen({ storeType, lines: [] });

    expect(getByText(title)).toBeOnTheScreen();
    expect(getByText(empty)).toBeOnTheScreen();
    expect(queryByTestId('cart-checkout')).toBeNull();
    await fireEvent.press(getByText('Browse stores'));
    expect(router.replace).toHaveBeenCalledWith(listRoute);
  });
});
