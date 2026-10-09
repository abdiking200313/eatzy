import { fireEvent } from '@testing-library/react-native';
import { Text } from 'react-native';

import { renderWithProviders } from '@/test-utils';

import { GradientActionButton } from './gradient-action-button';

describe('GradientActionButton', () => {
  it('renders the label and fires onPress when enabled', async () => {
    const onPress = jest.fn();
    const { getByText, getByRole } = await renderWithProviders(
      <GradientActionButton label="Get Started" onPress={onPress} />,
    );

    expect(getByText('Get Started')).toBeOnTheScreen();

    await fireEvent.press(getByRole('button'));

    expect(onPress).toHaveBeenCalledTimes(1);
  });

  it('is disabled and does not fire onPress when onPress is null', async () => {
    const onPress = jest.fn();
    const { getByRole } = await renderWithProviders(
      <GradientActionButton label="Checkout" onPress={null} />,
    );

    const button = getByRole('button');
    expect(button).toBeDisabled();

    await fireEvent.press(button);

    expect(onPress).not.toHaveBeenCalled();
  });

  it('is disabled when onPress is omitted entirely', async () => {
    const { getByRole } = await renderWithProviders(<GradientActionButton label="Checkout" />);

    expect(getByRole('button')).toBeDisabled();
  });

  it('renders a trailing icon when given one', async () => {
    const onPress = jest.fn();
    const { getByText } = await renderWithProviders(
      <GradientActionButton label="Checkout" onPress={onPress} icon={<Text>cart-icon</Text>} />,
    );

    expect(getByText('cart-icon')).toBeOnTheScreen();
  });
});
