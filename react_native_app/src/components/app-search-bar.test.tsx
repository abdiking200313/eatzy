import { fireEvent } from '@testing-library/react-native';

import { renderWithProviders } from '@/test-utils';

import { AppSearchBar } from './app-search-bar';

describe('AppSearchBar', () => {
  describe('editable mode', () => {
    it('renders the current value and reports changes', async () => {
      const onChangeText = jest.fn();
      const { getByDisplayValue } = await renderWithProviders(
        <AppSearchBar hintText="Search restaurants" value="piz" onChangeText={onChangeText} />,
      );

      const input = getByDisplayValue('piz');
      await fireEvent.changeText(input, 'pizza');

      expect(onChangeText).toHaveBeenCalledWith('pizza');
    });

    it('shows no clear button when the value is empty', async () => {
      const { queryByLabelText } = await renderWithProviders(
        <AppSearchBar hintText="Search restaurants" value="" onChangeText={jest.fn()} />,
      );

      expect(queryByLabelText('Clear')).toBeNull();
    });

    it('shows a clear button once there is text, clearing it on press', async () => {
      const onChangeText = jest.fn();
      const { getByLabelText } = await renderWithProviders(
        <AppSearchBar hintText="Search restaurants" value="pizza" onChangeText={onChangeText} />,
      );

      await fireEvent.press(getByLabelText('Clear'));

      expect(onChangeText).toHaveBeenCalledWith('');
    });

    it('calls a custom onClear instead of onChangeText("") when given one', async () => {
      const onChangeText = jest.fn();
      const onClear = jest.fn();
      const { getByLabelText } = await renderWithProviders(
        <AppSearchBar
          hintText="Search restaurants"
          value="pizza"
          onChangeText={onChangeText}
          onClear={onClear}
        />,
      );

      await fireEvent.press(getByLabelText('Clear'));

      expect(onClear).toHaveBeenCalledTimes(1);
      expect(onChangeText).not.toHaveBeenCalled();
    });
  });

  describe('tap-to-open mode', () => {
    it('renders the hint text as a read-only label and fires onPress when tapped', async () => {
      const onPress = jest.fn();
      const { getByText, getByRole } = await renderWithProviders(
        <AppSearchBar hintText="Search Zivo" onPress={onPress} />,
      );

      expect(getByText('Search Zivo')).toBeOnTheScreen();

      await fireEvent.press(getByRole('button'));

      expect(onPress).toHaveBeenCalledTimes(1);
    });

    it('renders no text input and no clear button', async () => {
      const { queryByLabelText, queryAllByDisplayValue } = await renderWithProviders(
        <AppSearchBar hintText="Search Zivo" onPress={jest.fn()} />,
      );

      expect(queryByLabelText('Clear')).toBeNull();
      expect(queryAllByDisplayValue('')).toHaveLength(0);
    });
  });
});
