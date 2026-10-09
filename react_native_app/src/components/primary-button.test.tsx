import { fireEvent } from '@testing-library/react-native';
import { Text } from 'react-native';

import { renderWithProviders } from '@/test-utils';
import { rawColors } from '@/theme/tokens';

import { PrimaryButton } from './primary-button';

describe('PrimaryButton', () => {
  it('renders the label and fires onPress', async () => {
    const onPress = jest.fn();
    const { getByText, getByRole } = await renderWithProviders(
      <PrimaryButton label="Save" onPress={onPress} />,
    );

    expect(getByText('Save')).toBeOnTheScreen();

    await fireEvent.press(getByRole('button'));

    expect(onPress).toHaveBeenCalledTimes(1);
  });

  it('renders an icon when given one', async () => {
    const { getByText } = await renderWithProviders(
      <PrimaryButton label="Save" onPress={jest.fn()} icon={<Text>icon</Text>} />,
    );

    expect(getByText('icon')).toBeOnTheScreen();
  });

  it('ignores a custom foregroundColor unless color is also overridden', async () => {
    const { getByText } = await renderWithProviders(
      <PrimaryButton label="Save" onPress={jest.fn()} foregroundColor={rawColors.stone900} />,
    );

    // The default foreground always follows the theme's onPrimary (white in
    // light mode), not the literal `foregroundColor` passed in, when `color`
    // is not also overridden.
    expect(getByText('Save')).not.toHaveStyle({ color: rawColors.stone900 });
  });

  it('applies both color and foregroundColor when color is overridden', async () => {
    const { getByText } = await renderWithProviders(
      <PrimaryButton
        label="Save"
        onPress={jest.fn()}
        color={rawColors.red600}
        foregroundColor={rawColors.stone900}
      />,
    );

    expect(getByText('Save')).toHaveStyle({ color: rawColors.stone900 });
  });
});
