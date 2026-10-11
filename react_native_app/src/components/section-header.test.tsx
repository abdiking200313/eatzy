/**
 * Ports the `SectionHeader` case from
 * `flutter_app/test/categories_screen_test.dart` (issue #544): the food
 * home section header's trailing action is optional.
 */
import { fireEvent } from '@testing-library/react-native';

import { renderWithProviders } from '@/test-utils';

import { SectionHeader } from './section-header';

describe('SectionHeader', () => {
  it('renders no action button when no action is given', async () => {
    const { getByText, queryByRole } = await renderWithProviders(<SectionHeader title="Orders" />);

    expect(getByText('Orders')).toBeOnTheScreen();
    expect(queryByRole('button')).toBeNull();
  });

  it('renders a pressable action when one is given', async () => {
    const onPress = jest.fn();
    const { getByRole } = await renderWithProviders(
      <SectionHeader title="Orders" actionLabel="See All" onPress={onPress} />,
    );

    await fireEvent.press(getByRole('button', { name: 'See All' }));

    expect(onPress).toHaveBeenCalledTimes(1);
  });
});
