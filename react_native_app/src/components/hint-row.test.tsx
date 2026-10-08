import { renderWithProviders } from '@/test-utils';

import { HintRow } from './hint-row';

describe('HintRow', () => {
  it('renders the default title and hint when no props are given', async () => {
    const { getByText } = await renderWithProviders(<HintRow />);

    expect(getByText('Try editing')).toBeOnTheScreen();
    expect(getByText('app/index.tsx')).toBeOnTheScreen();
  });

  it('renders a custom title and hint', async () => {
    const { getByText, queryByText } = await renderWithProviders(
      <HintRow title="Next step" hint="app/explore.tsx" />,
    );

    expect(getByText('Next step')).toBeOnTheScreen();
    expect(getByText('app/explore.tsx')).toBeOnTheScreen();
    expect(queryByText('Try editing')).toBeNull();
  });
});
