import { fireEvent } from '@testing-library/react-native';
import type { TestInstance } from 'test-renderer';

import { renderWithProviders } from '@/test-utils';

import { NetworkAvatar } from './network-avatar';

// See store-list-card.test.tsx's comment on this helper.
function findImage(container: TestInstance) {
  return container.queryAll((node) => node.type === 'ViewManagerAdapter_ExpoImage')[0];
}

// See store-list-card.test.tsx's comment on this helper.
function imageEvent() {
  return { nativeEvent: {} };
}

describe('NetworkAvatar', () => {
  it('renders a bare fallback circle when imageUrl is empty', async () => {
    const { container } = await renderWithProviders(<NetworkAvatar imageUrl="" />);

    expect(findImage(container)).toBeUndefined();
  });

  it('renders the image hidden (opacity 0) until it loads, then shows it', async () => {
    const { container } = await renderWithProviders(
      <NetworkAvatar imageUrl="https://example.com/avatar.jpg" />,
    );

    const image = findImage(container);
    expect(image).toHaveStyle({ opacity: 0 });

    await fireEvent(image, 'load', imageEvent());

    expect(findImage(container)).toHaveStyle({ opacity: 1 });
  });

  it('falls back to the bare circle again if the image fails to load', async () => {
    const { container } = await renderWithProviders(
      <NetworkAvatar imageUrl="https://example.com/avatar.jpg" />,
    );

    await fireEvent(findImage(container), 'error', imageEvent());

    expect(findImage(container)).toBeUndefined();
  });

  it('sizes the avatar from the radius prop', async () => {
    const { container } = await renderWithProviders(
      <NetworkAvatar imageUrl="https://example.com/avatar.jpg" radius={40} />,
    );

    expect(findImage(container)).toHaveStyle({ width: 80, height: 80 });
  });
});
