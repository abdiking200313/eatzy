import { renderWithProviders } from '@/test-utils';

import { SectionTitle } from './section-title';

describe('SectionTitle', () => {
  it('renders the title', async () => {
    const { getByText } = await renderWithProviders(<SectionTitle title="Popular Stores" />);

    expect(getByText('Popular Stores')).toBeOnTheScreen();
  });

  it('lets color and fontSize be overridden', async () => {
    const { getByText } = await renderWithProviders(
      <SectionTitle title="Nearby" color="#C2410C" fontSize={20} />,
    );

    expect(getByText('Nearby')).toHaveStyle({ color: '#C2410C', fontSize: 20 });
  });
});
