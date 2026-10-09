import { renderWithProviders } from '@/test-utils';

import { SummaryRow } from './summary-row';

describe('SummaryRow', () => {
  it('renders the label and value', async () => {
    const { getByText } = await renderWithProviders(<SummaryRow label="Subtotal" value="$12.00" />);

    expect(getByText('Subtotal')).toBeOnTheScreen();
    expect(getByText('$12.00')).toBeOnTheScreen();
  });

  it('renders a bold total row the same way as a regular row', async () => {
    const { getByText } = await renderWithProviders(
      <SummaryRow label="Total" value="$15.50" isBold />,
    );

    expect(getByText('Total')).toBeOnTheScreen();
    expect(getByText('$15.50')).toBeOnTheScreen();
  });
});
