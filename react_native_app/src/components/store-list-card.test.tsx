import { fireEvent } from '@testing-library/react-native';
import type { TestInstance } from 'test-renderer';

import { renderWithProviders } from '@/test-utils';

import { StoreListCard } from './store-list-card';

// `expo-image`'s `Image` is a composite component with no native-view
// double in this test renderer (Test Renderer v14+ only represents host
// elements) — its mocked host element's type is
// `ViewManagerAdapter_ExpoImage` (`expo-modules-core`'s
// `requireNativeViewManager('ExpoImage')` adapter, confirmed by dumping
// `container.toJSON()` under this jest config).
function findImage(container: TestInstance) {
  return container.queryAll((node) => node.type === 'ViewManagerAdapter_ExpoImage')[0];
}

// `expo-image`'s own `onLoad`/`onError` handlers (expo-image/src/ExpoImage.tsx)
// read `event.nativeEvent`, mirroring a real native synthetic event — a
// bare `fireEvent(image, 'load')` with no payload throws reading that off
// `undefined`.
function imageEvent() {
  return { nativeEvent: {} };
}

describe('StoreListCard', () => {
  const baseProps = {
    name: 'Bakaara Mart',
    subtitle: 'Bakaara',
    accentColor: '#C2410C',
    onPress: jest.fn(),
  };

  it('shows the "No picture available" placeholder when imageUrl is null', async () => {
    const { getByText, container } = await renderWithProviders(
      <StoreListCard {...baseProps} imageUrl={null} />,
    );

    expect(getByText('No picture available')).toBeOnTheScreen();
    expect(findImage(container)).toBeUndefined();
  });

  it('shows the "No picture available" placeholder when imageUrl is empty', async () => {
    const { getByText, container } = await renderWithProviders(
      <StoreListCard {...baseProps} imageUrl="" />,
    );

    expect(getByText('No picture available')).toBeOnTheScreen();
    expect(findImage(container)).toBeUndefined();
  });

  it('shows the photo, not the placeholder, once it loads', async () => {
    const { container, queryByText } = await renderWithProviders(
      <StoreListCard {...baseProps} imageUrl="https://example.com/store.jpg" />,
    );

    await fireEvent(findImage(container), 'load', imageEvent());

    expect(queryByText('No picture available')).toBeNull();
  });

  it('falls back to the placeholder if the photo fails to load', async () => {
    const { container, getByText } = await renderWithProviders(
      <StoreListCard {...baseProps} imageUrl="https://example.com/store.jpg" />,
    );

    await fireEvent(findImage(container), 'error', imageEvent());

    expect(getByText('No picture available')).toBeOnTheScreen();
  });

  it('always renders the name and subtitle', async () => {
    const { getByText } = await renderWithProviders(
      <StoreListCard {...baseProps} imageUrl={null} />,
    );

    expect(getByText('Bakaara Mart')).toBeOnTheScreen();
    expect(getByText('Bakaara')).toBeOnTheScreen();
  });

  it('fires onPress when tapped', async () => {
    const onPress = jest.fn();
    const { getByRole } = await renderWithProviders(
      <StoreListCard {...baseProps} onPress={onPress} imageUrl={null} />,
    );

    await fireEvent.press(getByRole('button'));

    expect(onPress).toHaveBeenCalledTimes(1);
  });
});
