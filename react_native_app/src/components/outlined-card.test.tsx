import { fireEvent } from '@testing-library/react-native';
import { Text } from 'react-native';

import { renderWithProviders } from '@/test-utils';

import { OutlinedCard } from './outlined-card';

describe('OutlinedCard', () => {
  it('renders its children', async () => {
    const { getByText } = await renderWithProviders(
      <OutlinedCard>
        <Text>Card content</Text>
      </OutlinedCard>,
    );

    expect(getByText('Card content')).toBeOnTheScreen();
  });

  it('is not pressable (no button role) when no onPress is given', async () => {
    const { queryByRole } = await renderWithProviders(
      <OutlinedCard>
        <Text>Static card</Text>
      </OutlinedCard>,
    );

    expect(queryByRole('button')).toBeNull();
  });

  it('becomes pressable and fires onPress when given one', async () => {
    const onPress = jest.fn();
    const { getByRole } = await renderWithProviders(
      <OutlinedCard onPress={onPress}>
        <Text>Tappable card</Text>
      </OutlinedCard>,
    );

    await fireEvent.press(getByRole('button'));

    expect(onPress).toHaveBeenCalledTimes(1);
  });
});
