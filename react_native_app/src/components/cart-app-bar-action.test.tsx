import { fireEvent } from '@testing-library/react-native';

import { renderWithProviders } from '@/test-utils';
import { ServiceThemes } from '@/theme/service-theme';

import { CartAppBarAction } from './cart-app-bar-action';

describe('CartAppBarAction', () => {
  it('fires onPress when tapped and exposes tooltip as its accessible name', async () => {
    const onPress = jest.fn();
    const { getByLabelText } = await renderWithProviders(
      <CartAppBarAction itemCount={0} onPress={onPress} tooltip="Food cart" />,
    );

    await fireEvent.press(getByLabelText('Food cart'));

    expect(onPress).toHaveBeenCalledTimes(1);
  });

  it('hides the count badge when itemCount is zero, but keeps the chip visible', async () => {
    const { getByLabelText, queryByText } = await renderWithProviders(
      <CartAppBarAction itemCount={0} onPress={jest.fn()} tooltip="Food cart" />,
    );

    expect(getByLabelText('Food cart')).toBeOnTheScreen();
    expect(queryByText('0')).toBeNull();
  });

  it('shows the count badge once itemCount is above zero', async () => {
    const { getByText } = await renderWithProviders(
      <CartAppBarAction itemCount={3} onPress={jest.fn()} tooltip="Food cart" />,
    );

    expect(getByText('3')).toBeOnTheScreen();
  });

  it('updates the badge text when itemCount changes', async () => {
    const { getByText, queryByText, rerender } = await renderWithProviders(
      <CartAppBarAction itemCount={1} onPress={jest.fn()} tooltip="Food cart" />,
    );

    expect(getByText('1')).toBeOnTheScreen();

    await rerender(<CartAppBarAction itemCount={5} onPress={jest.fn()} tooltip="Food cart" />);

    expect(getByText('5')).toBeOnTheScreen();
    expect(queryByText('1')).toBeNull();
  });

  it('badges the count in the platform accent by default', async () => {
    const { getByText } = await renderWithProviders(
      <CartAppBarAction itemCount={2} onPress={jest.fn()} tooltip="Cart" />,
    );

    expect(getByText('2').parent).toHaveStyle({ backgroundColor: ServiceThemes.platform.accent });
  });

  it("badges the count in the service's accent when given a service id", async () => {
    const { getByText } = await renderWithProviders(
      <CartAppBarAction itemCount={2} onPress={jest.fn()} tooltip="Cart" service="pharmacy" />,
    );

    expect(getByText('2').parent).toHaveStyle({ backgroundColor: ServiceThemes.pharmacy.accent });
  });

  it("fills the chip itself in the service's soft accent tint", async () => {
    const { getByRole } = await renderWithProviders(
      <CartAppBarAction itemCount={0} onPress={jest.fn()} tooltip="Cart" service="grocery" />,
    );

    expect(getByRole('button')).toHaveStyle({ backgroundColor: ServiceThemes.grocery.soft });
  });
});
