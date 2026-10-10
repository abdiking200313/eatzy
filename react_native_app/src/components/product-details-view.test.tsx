// flutter_app/test/ has no dedicated `ProductDetailsView` widget-test file --
// `grocery_screens_test.dart` and `pharmacy_screens_test.dart` only exercise
// its quantity stepper and "Add to cart" indirectly, through a full
// product-details *route* reached from a catalog screen (grocery's "tapping
// a product opens its details page, which adds the picked weight to the
// cart" and pharmacy's equivalent). Those two are ported below as directly
// as the shared `ProductDetailsView` component allows, along with reasonable
// coverage of the stepper's documented increment/decrement/max-steps/
// no-stock behavior.
import { fireEvent } from '@testing-library/react-native';
import { router } from 'expo-router';
import { Text } from 'react-native';

import { renderWithProviders } from '@/test-utils';

import { ProductDetailsView } from './product-details-view';

jest.mock('expo-router', () => ({
  router: {
    back: jest.fn(),
  },
}));

afterEach(() => {
  jest.clearAllMocks();
});

describe('ProductDetailsView', () => {
  const baseProps = {
    fallback: <Text>fallback-icon</Text>,
    name: 'Bananas',
    priceLabel: '$2.49',
    description: 'Sold by weight.',
    maxSteps: 4,
    quantityLabel: (steps: number) => `${steps} kg`,
    onAddToCart: jest.fn(),
  };

  it('renders the name, price, eyebrow, description and facts', async () => {
    const { getByText } = await renderWithProviders(
      <ProductDetailsView
        {...baseProps}
        eyebrow="Produce"
        facts={['Sold by weight, in 0.5 kg steps.']}
      />,
    );

    expect(getByText('Bananas')).toBeOnTheScreen();
    expect(getByText('$2.49')).toBeOnTheScreen();
    expect(getByText('Produce')).toBeOnTheScreen();
    expect(getByText('Sold by weight.')).toBeOnTheScreen();
    expect(getByText('Sold by weight, in 0.5 kg steps.')).toBeOnTheScreen();
  });

  it('shows the stock pill with the in-stock styling by default', async () => {
    const { getByText } = await renderWithProviders(
      <ProductDetailsView {...baseProps} stockLabel="In stock" />,
    );

    expect(getByText('In stock')).toBeOnTheScreen();
  });

  it('shows no stock pill when stockLabel is omitted', async () => {
    const { queryByText } = await renderWithProviders(<ProductDetailsView {...baseProps} />);

    expect(queryByText('In stock')).toBeNull();
  });

  it('starts the quantity picker at 1 step, and increase/decrease move it within [1, maxSteps]', async () => {
    const { getByText, getByLabelText } = await renderWithProviders(
      <ProductDetailsView {...baseProps} />,
    );

    expect(getByText('1 kg')).toBeOnTheScreen();

    await fireEvent.press(getByLabelText('Increase quantity'));
    expect(getByText('2 kg')).toBeOnTheScreen();

    await fireEvent.press(getByLabelText('Increase quantity'));
    expect(getByText('3 kg')).toBeOnTheScreen();

    await fireEvent.press(getByLabelText('Decrease quantity'));
    expect(getByText('2 kg')).toBeOnTheScreen();
  });

  it('disables decrease at 1 step, and does not go below it', async () => {
    const { getByLabelText, getByText } = await renderWithProviders(
      <ProductDetailsView {...baseProps} />,
    );

    const decrease = getByLabelText('Decrease quantity');
    expect(decrease).toBeDisabled();

    await fireEvent.press(decrease);

    expect(getByText('1 kg')).toBeOnTheScreen();
  });

  it('disables increase at maxSteps, and does not go above it', async () => {
    const { getByLabelText, getByText } = await renderWithProviders(
      <ProductDetailsView {...baseProps} maxSteps={2} />,
    );

    await fireEvent.press(getByLabelText('Increase quantity'));
    expect(getByText('2 kg')).toBeOnTheScreen();

    const increase = getByLabelText('Increase quantity');
    expect(increase).toBeDisabled();

    await fireEvent.press(increase);

    expect(getByText('2 kg')).toBeOnTheScreen();
  });

  it('hides the quantity picker and "Add to cart", and shows the unavailable label disabled, when maxSteps < 1', async () => {
    const onAddToCart = jest.fn();
    const { queryByLabelText, getByText } = await renderWithProviders(
      <ProductDetailsView {...baseProps} maxSteps={0} unavailableLabel="Out of stock" onAddToCart={onAddToCart} />,
    );

    expect(queryByLabelText('Increase quantity')).toBeNull();
    expect(queryByLabelText('Decrease quantity')).toBeNull();

    const label = getByText('Out of stock');
    expect(label).toBeDisabled();

    await fireEvent.press(label);

    expect(onAddToCart).not.toHaveBeenCalled();
  });

  it('navigates back, then calls onAddToCart with the chosen number of steps -- in that order', async () => {
    const calls: string[] = [];
    (router.back as jest.Mock).mockImplementation(() => calls.push('back'));
    const onAddToCart = jest.fn((steps: number) => calls.push(`add:${steps}`));

    const { getByLabelText, getByText } = await renderWithProviders(
      <ProductDetailsView {...baseProps} onAddToCart={onAddToCart} />,
    );

    await fireEvent.press(getByLabelText('Increase quantity'));
    await fireEvent.press(getByLabelText('Increase quantity'));

    await fireEvent.press(getByText('Add to cart'));

    expect(calls).toEqual(['back', 'add:3']);
    expect(onAddToCart).toHaveBeenCalledWith(3);
  });

  it('calls router.back() when the back button is pressed', async () => {
    const { getByLabelText } = await renderWithProviders(<ProductDetailsView {...baseProps} />);

    await fireEvent.press(getByLabelText('Back'));

    expect(router.back).toHaveBeenCalledTimes(1);
  });
});
