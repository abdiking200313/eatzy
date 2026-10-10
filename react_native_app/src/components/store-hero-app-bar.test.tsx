import { MaterialIcons } from '@expo/vector-icons';
import { fireEvent } from '@testing-library/react-native';
import { Text } from 'react-native';
import type { TestInstance } from 'test-renderer';

import { renderWithProviders } from '@/test-utils';

import { StoreHeroAppBar } from './store-hero-app-bar';

// See store-list-card.test.tsx's comment on this helper.
function findImage(container: TestInstance) {
  return container.queryAll((node) => node.type === 'ViewManagerAdapter_ExpoImage')[0];
}

// See store-list-card.test.tsx's comment on this helper.
function imageEvent() {
  return { nativeEvent: {} };
}

// See store-row-card.test.tsx's comment on this helper.
function glyph(icon: keyof typeof MaterialIcons.glyphMap) {
  return String.fromCodePoint(Number(MaterialIcons.glyphMap[icon]));
}

function findSpinner(container: TestInstance) {
  return container.queryAll((node) => node.type === 'ActivityIndicator')[0];
}

describe('StoreHeroAppBar', () => {
  const baseProps = {
    title: 'Bakaara Mart',
    fallbackIcon: 'storefront' as const,
  };

  it('renders the title', async () => {
    const { getByText } = await renderWithProviders(
      <StoreHeroAppBar {...baseProps} imageUrl={null} />,
    );

    expect(getByText('Bakaara Mart')).toBeOnTheScreen();
  });

  it('shows the fallback icon tile, with no spinner and no photo, when imageUrl is null', async () => {
    const { container, getByText } = await renderWithProviders(
      <StoreHeroAppBar {...baseProps} imageUrl={null} />,
    );

    expect(getByText(glyph('storefront'))).toBeOnTheScreen();
    expect(findSpinner(container)).toBeUndefined();
    expect(findImage(container)).toBeUndefined();
  });

  it('shows a spinner (not the icon) while a given photo is loading', async () => {
    const { container, queryByText } = await renderWithProviders(
      <StoreHeroAppBar {...baseProps} imageUrl="https://example.com/store.jpg" />,
    );

    expect(findSpinner(container)).toBeOnTheScreen();
    expect(queryByText(glyph('storefront'))).toBeNull();
    // The image is still mounted (so its onLoad/onError can fire) but
    // invisible until it finishes loading.
    expect(findImage(container)).toHaveStyle({ opacity: 0 });
  });

  it('reveals the photo once it loads, replacing the spinner', async () => {
    const { container } = await renderWithProviders(
      <StoreHeroAppBar {...baseProps} imageUrl="https://example.com/store.jpg" />,
    );

    await fireEvent(findImage(container), 'load', imageEvent());

    expect(findImage(container)).toHaveStyle({ opacity: 1 });
    expect(findSpinner(container)).toBeUndefined();
  });

  it('falls back to the icon tile (not the spinner) if the photo fails to load', async () => {
    const { container, getByText } = await renderWithProviders(
      <StoreHeroAppBar {...baseProps} imageUrl="https://example.com/store.jpg" />,
    );

    await fireEvent(findImage(container), 'error', imageEvent());

    expect(getByText(glyph('storefront'))).toBeOnTheScreen();
    expect(findSpinner(container)).toBeUndefined();
    expect(findImage(container)).toHaveStyle({ opacity: 0 });
  });

  it('shows no back button by default', async () => {
    const { queryByLabelText } = await renderWithProviders(
      <StoreHeroAppBar {...baseProps} imageUrl={null} />,
    );

    expect(queryByLabelText('Back')).toBeNull();
  });

  it('shows a back button when showBackButton is set, and fires onBackPress when tapped', async () => {
    const onBackPress = jest.fn();
    const { getByLabelText } = await renderWithProviders(
      <StoreHeroAppBar {...baseProps} imageUrl={null} showBackButton onBackPress={onBackPress} />,
    );

    const backButton = getByLabelText('Back');
    expect(backButton).toBeOnTheScreen();

    await fireEvent.press(backButton);

    expect(onBackPress).toHaveBeenCalledTimes(1);
  });

  it('renders actions when given', async () => {
    const { getByText } = await renderWithProviders(
      <StoreHeroAppBar {...baseProps} imageUrl={null} actions={<Text>cart-badge</Text>} />,
    );

    expect(getByText('cart-badge')).toBeOnTheScreen();
  });

  it('defaults imageFit to cover', async () => {
    const { container } = await renderWithProviders(
      <StoreHeroAppBar {...baseProps} imageUrl="https://example.com/store.jpg" />,
    );

    expect(findImage(container).props.contentFit).toBe('cover');
  });

  it('passes imageFit through to the photo', async () => {
    const { container } = await renderWithProviders(
      <StoreHeroAppBar
        {...baseProps}
        imageUrl="https://example.com/store.jpg"
        imageFit="contain"
      />,
    );

    expect(findImage(container).props.contentFit).toBe('contain');
  });

  it('passes testID through to the outer bar', async () => {
    const { getByTestId } = await renderWithProviders(
      <StoreHeroAppBar {...baseProps} imageUrl={null} testID="store-hero-bakaara" />,
    );

    expect(getByTestId('store-hero-bakaara')).toBeOnTheScreen();
  });
});
