import { renderWithProviders } from '@/test-utils';

import { StatusPill } from './status-pill';

describe('StatusPill', () => {
  it('renders the label', async () => {
    const { getByText } = await renderWithProviders(<StatusPill label="On the way" />);

    expect(getByText('On the way')).toBeOnTheScreen();
  });

  it('renders only the label (no leading icon) by default', async () => {
    const { getByText } = await renderWithProviders(<StatusPill label="Delivered" />);

    // The pill's icon (when present) is a sibling of the label `Text`,
    // rendered just before it — no icon means the label is the pill's only
    // child.
    expect(getByText('Delivered').parent!.children).toHaveLength(1);
  });

  it('renders a leading icon when given one', async () => {
    const { getByText } = await renderWithProviders(
      <StatusPill label="On the way" icon="local-shipping" />,
    );

    expect(getByText('On the way').parent!.children).toHaveLength(2);
  });

  it('lets backgroundColor/foregroundColor override the defaults', async () => {
    const { getByText } = await renderWithProviders(
      <StatusPill label="Cancelled" backgroundColor="#FEE2E2" foregroundColor="#B91C1C" />,
    );

    expect(getByText('Cancelled')).toHaveStyle({ color: '#B91C1C' });
    expect(getByText('Cancelled').parent).toHaveStyle({ backgroundColor: '#FEE2E2' });
  });
});
