import { renderWithProviders } from '@/test-utils';

import { ZivoLogo } from './zivo-logo';

describe('ZivoLogo', () => {
  it('renders the "zivo" wordmark by default', async () => {
    const { getByText } = await renderWithProviders(<ZivoLogo />);

    expect(getByText('zivo')).toBeOnTheScreen();
  });

  it('is labelled "Zivo" for accessibility, as a single image element', async () => {
    const { getByLabelText } = await renderWithProviders(<ZivoLogo />);

    expect(getByLabelText('Zivo')).toBeOnTheScreen();
  });

  it('hides the wordmark when showWordmark is false', async () => {
    const { queryByText, getByLabelText } = await renderWithProviders(
      <ZivoLogo showWordmark={false} />,
    );

    expect(queryByText('zivo')).toBeNull();
    // The mark itself still renders.
    expect(getByLabelText('Zivo')).toBeOnTheScreen();
  });

  it('lets wordmarkColor override the resolved theme color', async () => {
    const { getByText } = await renderWithProviders(<ZivoLogo wordmarkColor="#FF0000" />);

    expect(getByText('zivo')).toHaveStyle({ color: '#FF0000' });
  });
});
