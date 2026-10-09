import { fireEvent } from '@testing-library/react-native';
import { Text } from 'react-native';
import type { TestInstance } from 'test-renderer';

import { renderWithProviders } from '@/test-utils';

import { PhotoThumbnail } from './photo-thumbnail';

// See store-list-card.test.tsx's comment on this helper.
function findImage(container: TestInstance) {
  return container.queryAll((node) => node.type === 'ViewManagerAdapter_ExpoImage')[0];
}

// See store-list-card.test.tsx's comment on this helper.
function imageEvent() {
  return { nativeEvent: {} };
}

describe('PhotoThumbnail', () => {
  it('renders the fallback when there is no imageUrl', async () => {
    const { getByText, container } = await renderWithProviders(
      <PhotoThumbnail imageUrl={null} fallback={<Text>fallback-icon</Text>} />,
    );

    expect(getByText('fallback-icon')).toBeOnTheScreen();
    expect(findImage(container)).toBeUndefined();
  });

  it('renders the fallback when imageUrl is blank', async () => {
    const { getByText, container } = await renderWithProviders(
      <PhotoThumbnail imageUrl="   " fallback={<Text>fallback-icon</Text>} />,
    );

    expect(getByText('fallback-icon')).toBeOnTheScreen();
    expect(findImage(container)).toBeUndefined();
  });

  it('renders the photo, not the fallback, when imageUrl is set', async () => {
    const { container, queryByText } = await renderWithProviders(
      <PhotoThumbnail
        imageUrl="https://example.com/product.jpg"
        fallback={<Text>fallback-icon</Text>}
      />,
    );

    expect(findImage(container)).toBeOnTheScreen();
    expect(queryByText('fallback-icon')).toBeNull();
  });

  it('falls back to the fallback node if the photo fails to load', async () => {
    const { container, getByText } = await renderWithProviders(
      <PhotoThumbnail
        imageUrl="https://example.com/product.jpg"
        fallback={<Text>fallback-icon</Text>}
      />,
    );

    await fireEvent(findImage(container), 'error', imageEvent());

    expect(getByText('fallback-icon')).toBeOnTheScreen();
    expect(findImage(container)).toBeUndefined();
  });

  it('sizes the thumbnail from the size prop', async () => {
    const { container } = await renderWithProviders(
      <PhotoThumbnail
        imageUrl="https://example.com/product.jpg"
        fallback={<Text>fallback-icon</Text>}
        size={80}
      />,
    );

    expect(findImage(container)).toHaveStyle({ width: 80, height: 80 });
  });
});
