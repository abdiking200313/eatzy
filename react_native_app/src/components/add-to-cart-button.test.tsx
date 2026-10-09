import { fireEvent } from '@testing-library/react-native';

import { renderWithProviders } from '@/test-utils';

import { AddToCartButton } from './add-to-cart-button';

describe('AddToCartButton', () => {
  it('fires onPress when enabled, and exposes tooltip as its accessible name', async () => {
    const onPress = jest.fn();
    const { getByLabelText } = await renderWithProviders(
      <AddToCartButton tooltip="Add burger to cart" onPress={onPress} />,
    );

    const button = getByLabelText('Add burger to cart');
    expect(button).not.toBeDisabled();

    await fireEvent.press(button);

    expect(onPress).toHaveBeenCalledTimes(1);
  });

  it('is disabled and does not fire onPress when onPress is null', async () => {
    const onPress = jest.fn();
    const { getByLabelText } = await renderWithProviders(
      <AddToCartButton tooltip="Add medicine to cart" onPress={null} />,
    );

    const button = getByLabelText('Add medicine to cart');
    expect(button).toBeDisabled();

    await fireEvent.press(button);

    expect(onPress).not.toHaveBeenCalled();
  });

  it('is disabled when onPress is omitted', async () => {
    const { getByLabelText } = await renderWithProviders(
      <AddToCartButton tooltip="Add item to cart" />,
    );

    expect(getByLabelText('Add item to cart')).toBeDisabled();
  });
});
