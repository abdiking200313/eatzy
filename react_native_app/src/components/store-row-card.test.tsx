import { MaterialIcons } from '@expo/vector-icons';
import { fireEvent } from '@testing-library/react-native';
import type { TestInstance } from 'test-renderer';

import { renderWithProviders } from '@/test-utils';

import { StoreRowCard } from './store-row-card';

// See store-list-card.test.tsx's comment on this helper.
function findImage(container: TestInstance) {
  return container.queryAll((node) => node.type === 'ViewManagerAdapter_ExpoImage')[0];
}

// `@expo/vector-icons`' `MaterialIcons` renders a `Text` whose single child
// is the glyph's own code point character (confirmed by dumping
// `container.toJSON()` under this jest config) — there is no `name`/testID
// surviving onto the rendered host node to query by otherwise.
function glyph(icon: keyof typeof MaterialIcons.glyphMap) {
  return String.fromCodePoint(Number(MaterialIcons.glyphMap[icon]));
}

describe('StoreRowCard', () => {
  const baseProps = {
    name: 'Bakaara Mart',
    fallbackIcon: 'storefront' as const,
    onPress: jest.fn(),
  };

  it('renders the name', async () => {
    const { getByText } = await renderWithProviders(
      <StoreRowCard {...baseProps} imageUrl={null} />,
    );

    expect(getByText('Bakaara Mart')).toBeOnTheScreen();
  });

  it('renders each subtitle line', async () => {
    const { getByText } = await renderWithProviders(
      <StoreRowCard
        {...baseProps}
        imageUrl={null}
        subtitleLines={['123 Main St', 'Open until 9pm']}
      />,
    );

    expect(getByText('123 Main St')).toBeOnTheScreen();
    expect(getByText('Open until 9pm')).toBeOnTheScreen();
  });

  it('renders the caption when given', async () => {
    const { getByText } = await renderWithProviders(
      <StoreRowCard {...baseProps} imageUrl={null} caption="42 products" />,
    );

    expect(getByText('42 products')).toBeOnTheScreen();
  });

  it('renders no caption by default', async () => {
    const { queryByText } = await renderWithProviders(
      <StoreRowCard {...baseProps} imageUrl={null} />,
    );

    expect(queryByText(/products/)).toBeNull();
  });

  it('shows the photo, not the fallback icon tile, when imageUrl is set', async () => {
    const { container, queryByText } = await renderWithProviders(
      <StoreRowCard {...baseProps} imageUrl="https://example.com/store.jpg" />,
    );

    expect(findImage(container)).toBeOnTheScreen();
    expect(queryByText(glyph('storefront'))).toBeNull();
  });

  it('falls back to the ServiceIconChip tile when imageUrl is null', async () => {
    const { container, getByText } = await renderWithProviders(
      <StoreRowCard {...baseProps} imageUrl={null} />,
    );

    expect(findImage(container)).toBeUndefined();
    expect(getByText(glyph('storefront'))).toBeOnTheScreen();
  });

  it('falls back to the ServiceIconChip tile when imageUrl is empty', async () => {
    const { container, getByText } = await renderWithProviders(
      <StoreRowCard {...baseProps} imageUrl="" />,
    );

    expect(findImage(container)).toBeUndefined();
    expect(getByText(glyph('storefront'))).toBeOnTheScreen();
  });

  it('fires onPress when tapped', async () => {
    const onPress = jest.fn();
    const { getByRole } = await renderWithProviders(
      <StoreRowCard {...baseProps} onPress={onPress} imageUrl={null} />,
    );

    await fireEvent.press(getByRole('button'));

    expect(onPress).toHaveBeenCalledTimes(1);
  });

  it('passes testID through to the outer card', async () => {
    const { getByTestId } = await renderWithProviders(
      <StoreRowCard {...baseProps} imageUrl={null} testID="store-row-bakaara" />,
    );

    expect(getByTestId('store-row-bakaara')).toBeOnTheScreen();
  });
});
