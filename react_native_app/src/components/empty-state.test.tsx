import { renderWithProviders } from '@/test-utils';

import { EmptyState } from './empty-state';

describe('EmptyState', () => {
  it('renders the title', async () => {
    const { getByText } = await renderWithProviders(
      <EmptyState icon="receipt-long" title="No activity yet" />,
    );

    expect(getByText('No activity yet')).toBeOnTheScreen();
  });

  it('renders no supporting message by default', async () => {
    const { getByTestId } = await renderWithProviders(
      <EmptyState icon="receipt-long" title="No activity yet" />,
    );

    // The icon and title are the only children when no `message` is given.
    expect(getByTestId('empty-state').children).toHaveLength(2);
  });

  it('renders a supporting message when given one', async () => {
    const { getByText } = await renderWithProviders(
      <EmptyState
        icon="receipt-long"
        title="No activity yet"
        message="Your orders and bookings will appear here."
      />,
    );

    expect(getByText('Your orders and bookings will appear here.')).toBeOnTheScreen();
  });
});
