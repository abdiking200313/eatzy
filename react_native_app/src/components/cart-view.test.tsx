// Ports the shared-view cases from flutter_app/test/cart_screens_test.dart's
// `shared cart behavior` group, plus the per-vertical quantity/removal/empty
// behavior those tests exercise through a real `CartController` -- here
// against the plain presentational `CartView` directly (vertical screen
// wiring for food/grocery/pharmacy doesn't exist yet; see #382+).
import { fireEvent } from '@testing-library/react-native';
import { router } from 'expo-router';
import { Alert } from 'react-native';

import { renderWithProviders } from '@/test-utils';

import { CartView, type CartLine } from './cart-view';
import { checkoutLine } from './checkout-view';

jest.mock('expo-router', () => ({
  router: {
    canGoBack: jest.fn(() => false),
    back: jest.fn(),
    replace: jest.fn(),
  },
}));

describe('CartView', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  // Two lines with every amount distinct from the fee lines/total, mirroring
  // the Dart tests' own "so a per-line total never happens to equal the cart
  // subtotal/total" comment -- keeps every `getByText` below unambiguous.
  function makeLines(overrides: Partial<CartLine> = {}): CartLine[] {
    return [
      {
        id: 'burger-1',
        name: 'Classic Burger',
        total: 1599,
        quantityLabel: '1',
        unitPrice: 1599,
        onDecrease: jest.fn(),
        onIncrease: jest.fn(),
        onRemove: jest.fn(),
        ...overrides,
      },
      {
        id: 'fries-1',
        name: 'Side Fries',
        total: 499,
        quantityLabel: '1',
        unitPrice: 499,
        onDecrease: jest.fn(),
        onIncrease: jest.fn(),
        onRemove: jest.fn(),
      },
    ];
  }

  const baseProps = {
    isEmpty: false,
    emptyMessage: 'Your cart is empty',
    browseLabel: 'Browse stores',
    onBrowse: jest.fn(),
    feeLines: [checkoutLine('Subtotal', 2098), checkoutLine('Delivery fee', 250)],
    total: 2348,
    onCheckout: jest.fn(),
    fallbackIcon: 'restaurant' as const,
  };

  it('renders the store name, notice, lines, unit prices, and fee summary', async () => {
    const { getByText } = await renderWithProviders(
      <CartView {...baseProps} lines={makeLines()} storeName="Test Kitchen" notice="Heads up" />,
    );

    expect(getByText('Test Kitchen')).toBeOnTheScreen();
    expect(getByText('Heads up')).toBeOnTheScreen();
    expect(getByText('Classic Burger')).toBeOnTheScreen();
    expect(getByText('$15.99')).toBeOnTheScreen();
    expect(getByText('$15.99 each')).toBeOnTheScreen();
    expect(getByText('Side Fries')).toBeOnTheScreen();
    expect(getByText('$4.99')).toBeOnTheScreen();
    expect(getByText('Subtotal')).toBeOnTheScreen();
    expect(getByText('$20.98')).toBeOnTheScreen();
    expect(getByText('Delivery fee')).toBeOnTheScreen();
    expect(getByText('$2.50')).toBeOnTheScreen();
    expect(getByText('Total')).toBeOnTheScreen();
    expect(getByText('$23.48')).toBeOnTheScreen();
  });

  it('increasing a line calls only that line’s onIncrease', async () => {
    const lines = makeLines();
    const { getByTestId } = await renderWithProviders(<CartView {...baseProps} lines={lines} />);

    await fireEvent.press(getByTestId('increase-cart-item-burger-1'));

    expect(lines[0].onIncrease).toHaveBeenCalledTimes(1);
    expect(lines[0].onDecrease).not.toHaveBeenCalled();
    expect(lines[1].onIncrease).not.toHaveBeenCalled();
  });

  it('decreasing a line calls only that line’s onDecrease', async () => {
    const lines = makeLines();
    const { getByTestId } = await renderWithProviders(<CartView {...baseProps} lines={lines} />);

    await fireEvent.press(getByTestId('decrease-cart-item-fries-1'));

    expect(lines[1].onDecrease).toHaveBeenCalledTimes(1);
    expect(lines[0].onDecrease).not.toHaveBeenCalled();
  });

  it('removing a line calls only that line’s onRemove', async () => {
    const lines = makeLines();
    const { getByTestId } = await renderWithProviders(<CartView {...baseProps} lines={lines} />);

    await fireEvent.press(getByTestId('remove-cart-item-burger-1'));

    expect(lines[0].onRemove).toHaveBeenCalledTimes(1);
    expect(lines[1].onRemove).not.toHaveBeenCalled();
  });

  it('disables the increase button, and does not call it, when onIncrease is omitted (stock ceiling)', async () => {
    const lines = makeLines({ onIncrease: null });
    const { getByTestId } = await renderWithProviders(<CartView {...baseProps} lines={lines} />);

    const increase = getByTestId('increase-cart-item-burger-1');
    expect(increase).toBeDisabled();

    await fireEvent.press(increase);

    expect(lines[0].onIncrease).toBeNull();
  });

  it('disables the decrease button when onDecrease is omitted', async () => {
    const lines = makeLines({ onDecrease: undefined });
    const { getByTestId } = await renderWithProviders(<CartView {...baseProps} lines={lines} />);

    expect(getByTestId('decrease-cart-item-burger-1')).toBeDisabled();
  });

  it('shows the loading state and hides the lines and checkout button while isLoading', async () => {
    const { getByTestId, queryByTestId, queryByText } = await renderWithProviders(
      <CartView {...baseProps} isLoading lines={makeLines()} />,
    );

    expect(getByTestId('loading-state')).toBeOnTheScreen();
    expect(queryByText('Classic Burger')).toBeNull();
    expect(queryByTestId('cart-checkout')).toBeNull();
  });

  it('shows the empty state with no checkout button, and fires onBrowse', async () => {
    const onBrowse = jest.fn();
    const { getByText, queryByTestId } = await renderWithProviders(
      <CartView {...baseProps} isEmpty lines={[]} onBrowse={onBrowse} />,
    );

    expect(getByText('Your cart is empty')).toBeOnTheScreen();
    expect(queryByTestId('cart-checkout')).toBeNull();

    await fireEvent.press(getByText('Browse stores'));

    expect(onBrowse).toHaveBeenCalledTimes(1);
  });

  it('shows the total in the checkout button label and fires onCheckout when pressed', async () => {
    const onCheckout = jest.fn();
    const { getByText, getByTestId } = await renderWithProviders(
      <CartView {...baseProps} lines={makeLines()} onCheckout={onCheckout} />,
    );

    expect(getByText('Continue to checkout • $23.48')).toBeOnTheScreen();

    await fireEvent.press(getByTestId('cart-checkout'));

    expect(onCheckout).toHaveBeenCalledTimes(1);
  });

  it('shows "Calculated at checkout" and omits an amount from the button label when total is null', async () => {
    const { getByText, queryByText } = await renderWithProviders(
      <CartView {...baseProps} lines={makeLines()} total={null} />,
    );

    expect(getByText('Calculated at checkout')).toBeOnTheScreen();
    expect(getByText('Continue to checkout')).toBeOnTheScreen();
    expect(queryByText('Continue to checkout • $23.48')).toBeNull();
  });

  it('shows no Clear action when onClear is omitted', async () => {
    const { queryByText } = await renderWithProviders(<CartView {...baseProps} lines={makeLines()} />);

    expect(queryByText('Clear')).toBeNull();
  });

  it('shows no Clear action when the cart is empty, even if onClear is given', async () => {
    const { queryByText } = await renderWithProviders(
      <CartView {...baseProps} isEmpty lines={[]} onClear={jest.fn()} />,
    );

    expect(queryByText('Clear')).toBeNull();
  });

  it('confirms before clearing, and calls onClear only once "Clear cart" is confirmed', async () => {
    const onClear = jest.fn();
    const alertSpy = jest.spyOn(Alert, 'alert').mockImplementation(() => {});
    const { getByText } = await renderWithProviders(
      <CartView {...baseProps} lines={makeLines()} onClear={onClear} />,
    );

    await fireEvent.press(getByText('Clear'));

    expect(alertSpy).toHaveBeenCalledTimes(1);
    const [title, message, buttons] = alertSpy.mock.calls[0];
    expect(title).toBe('Clear your cart?');
    expect(message).toBe('This will remove every item from your cart.');
    expect(buttons).toEqual([
      { text: 'Cancel', style: 'cancel' },
      { text: 'Clear cart', style: 'destructive', onPress: expect.any(Function) },
    ]);
    expect(onClear).not.toHaveBeenCalled();

    buttons?.[1]?.onPress?.();

    expect(onClear).toHaveBeenCalledTimes(1);

    alertSpy.mockRestore();
  });

  it('falls back to router.replace when the back button cannot go back', async () => {
    (router.canGoBack as jest.Mock).mockReturnValue(false);
    const { getByLabelText } = await renderWithProviders(<CartView {...baseProps} lines={makeLines()} />);

    await fireEvent.press(getByLabelText('Back'));

    expect(router.replace).toHaveBeenCalledWith('/');
  });
});
