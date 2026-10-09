import { fireEvent } from '@testing-library/react-native';

import { renderWithProviders } from '@/test-utils';

import { AppTextField } from './app-text-field';

describe('AppTextField', () => {
  it('renders the hint as a placeholder and reports text changes', async () => {
    const onChangeText = jest.fn();
    const { getByPlaceholderText } = await renderWithProviders(
      <AppTextField hint="Email address" onChangeText={onChangeText} />,
    );

    const input = getByPlaceholderText('Email address');
    await fireEvent.changeText(input, 'amina@example.com');

    expect(onChangeText).toHaveBeenCalledWith('amina@example.com');
  });

  it('renders a label above the field when given one', async () => {
    const { getByText } = await renderWithProviders(
      <AppTextField hint="Email address" label="Email" />,
    );

    expect(getByText('Email')).toBeOnTheScreen();
  });

  it('renders no label when none is given', async () => {
    const { queryByText } = await renderWithProviders(<AppTextField hint="Email address" />);

    expect(queryByText('Email')).toBeNull();
  });

  it('calls onSubmitted with the current text', async () => {
    const onSubmitted = jest.fn();
    const { getByPlaceholderText } = await renderWithProviders(
      <AppTextField hint="Email address" value="a@b.com" onSubmitted={onSubmitted} />,
    );

    fireEvent(getByPlaceholderText('Email address'), 'submitEditing', {
      nativeEvent: { text: 'a@b.com' },
    });

    expect(onSubmitted).toHaveBeenCalledWith('a@b.com');
  });

  describe('obscureText', () => {
    it('starts hidden and toggles to shown on press', async () => {
      const { getByLabelText } = await renderWithProviders(
        <AppTextField hint="Password" obscureText />,
      );

      expect(getByLabelText('Show password')).toBeOnTheScreen();

      await fireEvent.press(getByLabelText('Show password'));

      expect(getByLabelText('Hide password')).toBeOnTheScreen();
    });

    it('renders no visibility toggle when obscureText is false', async () => {
      const { queryByLabelText } = await renderWithProviders(<AppTextField hint="Name" />);

      expect(queryByLabelText('Show password')).toBeNull();
      expect(queryByLabelText('Hide password')).toBeNull();
    });
  });

  describe('readOnly / onPress (tap-to-open)', () => {
    it('fires onPress when tapped and does not forward typed text when readOnly', async () => {
      const onPress = jest.fn();
      const onChangeText = jest.fn();
      const { getByRole } = await renderWithProviders(
        <AppTextField
          hint="Delivery address"
          value="123 Main St"
          readOnly
          onPress={onPress}
          onChangeText={onChangeText}
        />,
      );

      await fireEvent.press(getByRole('button'));

      expect(onPress).toHaveBeenCalledTimes(1);
    });
  });
});
