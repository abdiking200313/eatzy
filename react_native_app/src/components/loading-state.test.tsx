import { renderWithProviders } from '@/test-utils';

import { LoadingState } from './loading-state';

describe('LoadingState', () => {
  it('renders a spinner', async () => {
    const { getByTestId } = await renderWithProviders(<LoadingState />);

    expect(getByTestId('loading-state')).toBeOnTheScreen();
  });

  it('renders no caption by default', async () => {
    const { getByTestId } = await renderWithProviders(<LoadingState />);

    // The spinner is the only child when no `message` is given.
    expect(getByTestId('loading-state').children).toHaveLength(1);
  });

  it('renders a caption when given a message', async () => {
    const { getByText } = await renderWithProviders(<LoadingState message="Loading menu…" />);

    expect(getByText('Loading menu…')).toBeOnTheScreen();
  });
});
