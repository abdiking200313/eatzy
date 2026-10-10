// Ports the shared-view cases from
// flutter_app/test/checkout_screens_test.dart that are about `CheckoutView`
// itself (the optional delivery note, the order summary, "Pay on delivery",
// and the "Place order" button) rather than a vertical's own `CheckoutScreen`
// wiring, which doesn't exist yet (see #382+). The double-tap guard and
// validation-flagging cases in that file are driven by each vertical's own
// controller/screen, not by this presentational component, and are out of
// scope here for the same reason.
import { fireEvent } from '@testing-library/react-native';
import { Text } from 'react-native';

import { renderWithProviders } from '@/test-utils';

import {
  CheckoutDeliveryNote,
  CheckoutEmptyState,
  checkoutLine,
  checkoutLineDisplayValue,
  CheckoutSummaryCard,
  CheckoutView,
  FeeSummaryRow,
  pendingCheckoutLine,
  type CheckoutLine,
} from './checkout-view';

jest.mock('expo-router', () => ({
  router: {
    canGoBack: jest.fn(() => false),
    back: jest.fn(),
    replace: jest.fn(),
  },
}));

afterEach(() => {
  jest.clearAllMocks();
});

describe('checkoutLine / pendingCheckoutLine / checkoutLineDisplayValue', () => {
  it('builds a non-pending line and displays it as formatted money', () => {
    const line = checkoutLine('Subtotal', 1599);

    expect(line).toEqual({ label: 'Subtotal', amount: 1599, isPending: false });
    expect(checkoutLineDisplayValue(line)).toBe('$15.99');
  });

  it('builds a pending line (amount kept 0) that displays as "Calculated at checkout"', () => {
    const line = pendingCheckoutLine('Delivery fee');

    expect(line).toEqual({ label: 'Delivery fee', amount: 0, isPending: true });
    expect(checkoutLineDisplayValue(line)).toBe('Calculated at checkout');
  });
});

describe('FeeSummaryRow', () => {
  it('renders the label and value', async () => {
    const { getByText } = await renderWithProviders(<FeeSummaryRow label="Total" value="$23.48" />);

    expect(getByText('Total')).toBeOnTheScreen();
    expect(getByText('$23.48')).toBeOnTheScreen();
  });
});

describe('CheckoutEmptyState', () => {
  it('shows the message and browse label, and fires onBrowse', async () => {
    const onBrowse = jest.fn();
    const { getByText } = await renderWithProviders(
      <CheckoutEmptyState message="Your cart is empty" browseLabel="Browse stores" onBrowse={onBrowse} />,
    );

    expect(getByText('Your cart is empty')).toBeOnTheScreen();

    await fireEvent.press(getByText('Browse stores'));

    expect(onBrowse).toHaveBeenCalledTimes(1);
  });
});

describe('CheckoutDeliveryNote', () => {
  it('renders the controlled note value and the static helper copy', async () => {
    const { getByTestId, getByText } = await renderWithProviders(
      <CheckoutDeliveryNote note="Blue gate" onNoteChange={jest.fn()} />,
    );

    expect(getByText('Delivery note / landmark (optional)')).toBeOnTheScreen();
    expect(getByTestId('checkout-delivery-note').props.value).toBe('Blue gate');
  });

  it('fires onNoteChange with the typed text', async () => {
    const onNoteChange = jest.fn();
    const { getByTestId } = await renderWithProviders(
      <CheckoutDeliveryNote note="" onNoteChange={onNoteChange} />,
    );

    fireEvent.changeText(getByTestId('checkout-delivery-note'), 'Blue gate');

    expect(onNoteChange).toHaveBeenCalledWith('Blue gate');
  });
});

describe('CheckoutSummaryCard', () => {
  // Every amount is distinct so no `getByText` below is ambiguous (mirrors
  // the Dart tests' own "so a per-line total never happens to equal the cart
  // subtotal/total" comment).
  const itemLines: CheckoutLine[] = [checkoutLine('Classic Burger ×1', 1599)];
  const feeLines: CheckoutLine[] = [checkoutLine('Subtotal', 2098), checkoutLine('Delivery fee', 250)];

  it('renders item lines, fee lines, the total, and "Pay on delivery"', async () => {
    const { getByText } = await renderWithProviders(
      <CheckoutSummaryCard itemLines={itemLines} feeLines={feeLines} total={2348} />,
    );

    expect(getByText('Order summary')).toBeOnTheScreen();
    expect(getByText('Classic Burger ×1')).toBeOnTheScreen();
    expect(getByText('$15.99')).toBeOnTheScreen();
    expect(getByText('Subtotal')).toBeOnTheScreen();
    expect(getByText('$20.98')).toBeOnTheScreen();
    expect(getByText('Delivery fee')).toBeOnTheScreen();
    expect(getByText('$2.50')).toBeOnTheScreen();
    expect(getByText('Total')).toBeOnTheScreen();
    expect(getByText('$23.48')).toBeOnTheScreen();
    expect(getByText('Pay on delivery')).toBeOnTheScreen();
  });

  it('shows "Calculated at checkout" for a pending fee line and for a null total', async () => {
    const { getByText, getAllByText } = await renderWithProviders(
      <CheckoutSummaryCard
        itemLines={itemLines}
        feeLines={[checkoutLine('Subtotal', 1599), pendingCheckoutLine('Delivery fee')]}
        total={null}
      />,
    );

    // One for the pending delivery fee, one for the null total.
    expect(getAllByText('Calculated at checkout')).toHaveLength(2);
    expect(getByText('Delivery fee')).toBeOnTheScreen();
  });
});

describe('CheckoutView', () => {
  const baseProps = {
    title: 'Checkout',
    isEmpty: false,
    emptyMessage: 'Your cart is empty',
    browseLabel: 'Browse stores',
    onBrowse: jest.fn(),
    note: '',
    onNoteChange: jest.fn(),
    itemLines: [checkoutLine('Classic Burger ×1', 1599)] as CheckoutLine[],
    feeLines: [checkoutLine('Subtotal', 1599)] as CheckoutLine[],
    total: 1599,
    isSubmitting: false,
    onSubmit: jest.fn(),
  };

  it('shows the loading state and hides the summary and submit button', async () => {
    const { getByTestId, queryByTestId, queryByText } = await renderWithProviders(
      <CheckoutView {...baseProps} isLoading />,
    );

    expect(getByTestId('loading-state')).toBeOnTheScreen();
    expect(queryByText('Order summary')).toBeNull();
    expect(queryByTestId('checkout-place-order')).toBeNull();
  });

  it('shows the empty state with no submit button, and fires onBrowse', async () => {
    const onBrowse = jest.fn();
    const { getByText, queryByTestId } = await renderWithProviders(
      <CheckoutView {...baseProps} isEmpty onBrowse={onBrowse} />,
    );

    expect(getByText('Your cart is empty')).toBeOnTheScreen();
    expect(queryByTestId('checkout-place-order')).toBeNull();

    await fireEvent.press(getByText('Browse stores'));

    expect(onBrowse).toHaveBeenCalledTimes(1);
  });

  it('shows the total in the submit button label, and fires onSubmit when pressed', async () => {
    const onSubmit = jest.fn();
    const { getByText, getByTestId } = await renderWithProviders(
      <CheckoutView {...baseProps} onSubmit={onSubmit} />,
    );

    expect(getByText('Place order • $15.99')).toBeOnTheScreen();

    await fireEvent.press(getByTestId('checkout-place-order'));

    expect(onSubmit).toHaveBeenCalledTimes(1);
  });

  it('omits an amount from the submit button label when total is null', async () => {
    const { getByText, queryByText } = await renderWithProviders(
      <CheckoutView {...baseProps} total={null} />,
    );

    expect(getByText('Place order')).toBeOnTheScreen();
    expect(queryByText('Place order • $15.99')).toBeNull();
  });

  it('shows "Placing order..." and disables the submit button while isSubmitting', async () => {
    const onSubmit = jest.fn();
    const { getByText, getByTestId } = await renderWithProviders(
      <CheckoutView {...baseProps} isSubmitting onSubmit={onSubmit} />,
    );

    const button = getByTestId('checkout-place-order');
    expect(getByText('Placing order...')).toBeOnTheScreen();
    expect(button).toBeDisabled();

    await fireEvent.press(button);

    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('shows the error text with its testID when errorText is set', async () => {
    const { getByTestId, getByText } = await renderWithProviders(
      <CheckoutView {...baseProps} errorText="The food order could not be saved. Please try again." />,
    );

    expect(getByTestId('checkout-error')).toBeOnTheScreen();
    expect(getByText('The food order could not be saved. Please try again.')).toBeOnTheScreen();
  });

  it('shows no error text when errorText is omitted or null', async () => {
    const { queryByTestId, rerender } = await renderWithProviders(<CheckoutView {...baseProps} />);
    expect(queryByTestId('checkout-error')).toBeNull();

    rerender(<CheckoutView {...baseProps} errorText={null} />);
    expect(queryByTestId('checkout-error')).toBeNull();
  });

  it('wires the controlled note through to CheckoutDeliveryNote', async () => {
    const onNoteChange = jest.fn();
    const { getByTestId } = await renderWithProviders(
      <CheckoutView {...baseProps} note="Blue gate" onNoteChange={onNoteChange} />,
    );

    const input = getByTestId('checkout-delivery-note');
    expect(input.props.value).toBe('Blue gate');

    fireEvent.changeText(input, 'Near the mosque');

    expect(onNoteChange).toHaveBeenCalledWith('Near the mosque');
  });

  it('renders vertical-specific extraSections', async () => {
    const { getByText } = await renderWithProviders(
      <CheckoutView {...baseProps} extraSections={[<Text key="slot">Choose a delivery slot</Text>]} />,
    );

    expect(getByText('Choose a delivery slot')).toBeOnTheScreen();
  });
});
