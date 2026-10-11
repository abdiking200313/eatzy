/**
 * Screen-reader contract for the shared interactive components (issue #416):
 * every control exposes a role, an accessible name, and its state, queried
 * the way TalkBack/VoiceOver would see them (`getByRole`/`getByLabelText`)
 * rather than by testID or raw text.
 */
import { fireEvent } from '@testing-library/react-native';
import { Text } from 'react-native';

import { renderWithProviders } from '@/test-utils';

import { AddToCartButton } from './add-to-cart-button';
import { AppTextField } from './app-text-field';
import { CategoryChipBar } from './category-chip-bar';
import { GradientActionButton } from './gradient-action-button';
import { LoadingState } from './loading-state';
import { MenuItemCard } from './menu-item-card';
import { OutlinedCard } from './outlined-card';
import { PrimaryButton } from './primary-button';
import { SectionHeader } from './section-header';
import { SectionTitle } from './section-title';

describe('shared component accessibility', () => {
  it('PrimaryButton is a button named by its label', async () => {
    const onPress = jest.fn();
    const { getByRole } = await renderWithProviders(<PrimaryButton label="Save" onPress={onPress} />);

    await fireEvent.press(getByRole('button', { name: 'Save' }));

    expect(onPress).toHaveBeenCalledTimes(1);
  });

  it('GradientActionButton exposes its disabled state when it has no onPress', async () => {
    const { getByRole, rerender } = await renderWithProviders(<GradientActionButton label="Checkout" onPress={null} />);

    expect(getByRole('button', { name: 'Checkout' })).toBeDisabled();

    await rerender(<GradientActionButton label="Checkout" onPress={jest.fn()} />);

    expect(getByRole('button', { name: 'Checkout' })).toBeEnabled();
  });

  it('AddToCartButton (icon-only) is named by its tooltip and reports disabled', async () => {
    const { getByRole } = await renderWithProviders(<AddToCartButton tooltip="Out of stock" onPress={null} />);

    expect(getByRole('button', { name: 'Out of stock' })).toBeDisabled();
  });

  describe('AppTextField', () => {
    it('names the input by its visible label', async () => {
      const onChangeText = jest.fn();
      const { getByLabelText } = await renderWithProviders(
        <AppTextField label="Email" hint="you@example.com" onChangeText={onChangeText} />,
      );

      await fireEvent.changeText(getByLabelText('Email'), 'amina@example.com');

      expect(onChangeText).toHaveBeenCalledWith('amina@example.com');
    });

    it('falls back to the hint as the name when there is no label', async () => {
      const { getByLabelText } = await renderWithProviders(<AppTextField hint="Email address" />);

      expect(getByLabelText('Email address')).toBeOnTheScreen();
    });

    it('names the password toggle and flips it on press', async () => {
      const { getByRole } = await renderWithProviders(<AppTextField hint="Password" obscureText />);

      await fireEvent.press(getByRole('button', { name: 'Show password' }));

      expect(getByRole('button', { name: 'Hide password' })).toBeOnTheScreen();
    });

    it('announces a tap-to-open field by its name and current value', async () => {
      const onPress = jest.fn();
      const { getByRole } = await renderWithProviders(
        <AppTextField hint="Delivery address" value="123 Main St" readOnly onPress={onPress} />,
      );

      const field = getByRole('button', { name: 'Delivery address' });
      expect(field).toHaveAccessibilityValue({ text: '123 Main St' });

      await fireEvent.press(field);
      expect(onPress).toHaveBeenCalledTimes(1);
    });
  });

  describe('OutlinedCard', () => {
    it('passes an explicit label and hint through to the pressable card', async () => {
      const { getByRole } = await renderWithProviders(
        <OutlinedCard onPress={jest.fn()} accessibilityLabel="Burger Hub" accessibilityHint="Opens the store">
          <Text>Burger Hub</Text>
        </OutlinedCard>,
      );

      expect(getByRole('button', { name: 'Burger Hub' }).props.accessibilityHint).toBe('Opens the store');
    });
  });

  describe('MenuItemCard', () => {
    const item = { id: 'm1', name: 'Burger', description: 'Beef patty', price: 1250, imageUrl: '' };

    it('exposes add-to-cart as a screen-reader action on the card itself', async () => {
      const onAddToCart = jest.fn();
      const onPress = jest.fn();
      const { getByTestId } = await renderWithProviders(
        <MenuItemCard item={item} onPress={onPress} onAddToCart={onAddToCart} />,
      );

      const card = getByTestId('menu-item-card-m1');
      expect(card.props.accessibilityHint).toBe('Opens item details');
      expect(card.props.accessibilityActions).toEqual([{ name: 'addToCart', label: 'Add Burger to cart' }]);

      await fireEvent(card, 'accessibilityAction', { nativeEvent: { actionName: 'addToCart' } });

      expect(onAddToCart).toHaveBeenCalledTimes(1);
      expect(onPress).not.toHaveBeenCalled();
    });

    it('keeps the nested add button labelled for TalkBack/touch exploration', async () => {
      const { getByRole } = await renderWithProviders(
        <MenuItemCard item={item} onPress={jest.fn()} onAddToCart={jest.fn()} />,
      );

      expect(getByRole('button', { name: 'Add Burger to cart' })).toBeOnTheScreen();
    });
  });

  it('CategoryChipBar marks only the selected chip as selected', async () => {
    const { getByRole } = await renderWithProviders(
      <CategoryChipBar
        categories={[
          { id: 'a', name: 'Pizza' },
          { id: 'b', name: 'Sushi' },
        ]}
        selectedCategoryId="b"
        onSelected={jest.fn()}
      />,
    );

    expect(getByRole('button', { name: 'Sushi' })).toBeSelected();
    expect(getByRole('button', { name: 'Pizza' })).not.toBeSelected();
  });

  it('SectionTitle and SectionHeader titles are headings', async () => {
    const { getByRole } = await renderWithProviders(
      <>
        <SectionTitle title="Delivery" />
        <SectionHeader title="Categories" actionLabel="See All" onPress={jest.fn()} />
      </>,
    );

    expect(getByRole('header', { name: 'Delivery' })).toBeOnTheScreen();
    expect(getByRole('header', { name: 'Categories' })).toBeOnTheScreen();
    expect(getByRole('button', { name: 'See All' })).toBeOnTheScreen();
  });

  it('LoadingState announces a progress indicator', async () => {
    const { getByRole, rerender } = await renderWithProviders(<LoadingState />);

    expect(getByRole('progressbar', { name: 'Loading' })).toBeOnTheScreen();

    await rerender(<LoadingState message="Loading menu…" />);

    expect(getByRole('progressbar', { name: 'Loading menu…' })).toBeOnTheScreen();
  });
});
