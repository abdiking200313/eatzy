import { renderWithProviders } from '@/test-utils';
import { ServiceThemes } from '@/theme/service-theme';

import { SERVICE_ICON_CHIP_DEFAULT_SIZE, ServiceIconChip } from './service-icon-chip';

describe('ServiceIconChip', () => {
  it('falls back to the neutral platform palette when no service is given', async () => {
    const { root } = await renderWithProviders(<ServiceIconChip icon="restaurant" />);

    expect(root).toHaveStyle({ backgroundColor: ServiceThemes.platform.accent });
  });

  it("uses the service's accent palette when given a service id", async () => {
    const { root } = await renderWithProviders(
      <ServiceIconChip icon="local-pharmacy" service="pharmacy" />,
    );

    expect(root).toHaveStyle({ backgroundColor: ServiceThemes.pharmacy.accent });
  });

  it("uses a slug's palette (e.g. Fresh Meat) over the plain service palette", async () => {
    const { root } = await renderWithProviders(
      <ServiceIconChip icon="icecream" service="grocery" slug="fresh-meat" />,
    );

    expect(root).toHaveStyle({ backgroundColor: ServiceThemes.freshMeat.accent });
  });

  it('lets an explicit background override the palette', async () => {
    const { root } = await renderWithProviders(
      <ServiceIconChip icon="restaurant" background="#000000" />,
    );

    expect(root).toHaveStyle({ backgroundColor: '#000000' });
  });

  it('defaults to a 48x48 chip', async () => {
    const { root } = await renderWithProviders(<ServiceIconChip icon="restaurant" />);

    expect(SERVICE_ICON_CHIP_DEFAULT_SIZE).toBe(48);
    expect(root).toHaveStyle({
      width: SERVICE_ICON_CHIP_DEFAULT_SIZE,
      height: SERVICE_ICON_CHIP_DEFAULT_SIZE,
    });
  });

  it('resizes the chip from the size prop', async () => {
    const { root } = await renderWithProviders(<ServiceIconChip icon="restaurant" size={64} />);

    expect(root).toHaveStyle({ width: 64, height: 64 });
  });
});
