import type { TestInstance } from 'test-renderer';

import { renderWithProviders } from '@/test-utils';
import { ServiceThemes } from '@/theme/service-theme';

import { ServicePhotoChip } from './service-photo-chip';

// See store-list-card.test.tsx's comment on this helper.
function findImage(container: TestInstance) {
  return container.queryAll((node) => node.type === 'ViewManagerAdapter_ExpoImage')[0];
}

describe('ServicePhotoChip', () => {
  it("renders the photo (via NetworkAvatar's Image) for the given imageUrl", async () => {
    const { container } = await renderWithProviders(
      <ServicePhotoChip imageUrl="https://example.com/store.jpg" />,
    );

    expect(findImage(container).props.source).toEqual([{ uri: 'https://example.com/store.jpg' }]);
  });

  it('rings the chip in the platform accent by default', async () => {
    const { container } = await renderWithProviders(
      <ServicePhotoChip imageUrl="https://example.com/store.jpg" />,
    );

    // The image's grandparent is the ring `View` — the image's own parent is
    // `NetworkAvatar`'s background `View`.
    const ring = findImage(container).parent!.parent!;
    expect(ring).toHaveStyle({ borderColor: ServiceThemes.platform.accent });
  });

  it("rings the chip in the service's accent when given a service id", async () => {
    const { container } = await renderWithProviders(
      <ServicePhotoChip imageUrl="https://example.com/store.jpg" service="grocery" />,
    );

    const ring = findImage(container).parent!.parent!;
    expect(ring).toHaveStyle({ borderColor: ServiceThemes.grocery.accent });
  });

  it('lets an explicit ringColor override the palette', async () => {
    const { container } = await renderWithProviders(
      <ServicePhotoChip imageUrl="https://example.com/store.jpg" ringColor="#123456" />,
    );

    const ring = findImage(container).parent!.parent!;
    expect(ring).toHaveStyle({ borderColor: '#123456' });
  });
});
