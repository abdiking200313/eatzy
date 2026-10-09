import { fireEvent } from '@testing-library/react-native';

import { renderWithProviders } from '@/test-utils';

import { ErrorState } from './error-state';

describe('ErrorState', () => {
  it('renders the error message', async () => {
    const { getByText } = await renderWithProviders(
      <ErrorState message="Something went wrong." onRetry={jest.fn()} />,
    );

    expect(getByText('Something went wrong.')).toBeOnTheScreen();
  });

  it('renders a "Try again" retry button by default', async () => {
    const { getByText } = await renderWithProviders(
      <ErrorState message="Something went wrong." onRetry={jest.fn()} />,
    );

    expect(getByText('Try again')).toBeOnTheScreen();
  });

  it('calls onRetry when the retry button is pressed', async () => {
    const onRetry = jest.fn();
    const { getByRole } = await renderWithProviders(
      <ErrorState message="Something went wrong." onRetry={onRetry} />,
    );

    await fireEvent.press(getByRole('button'));

    expect(onRetry).toHaveBeenCalledTimes(1);
  });

  it('lets retryLabel override the default button label', async () => {
    const { getByText, queryByText } = await renderWithProviders(
      <ErrorState message="Something went wrong." onRetry={jest.fn()} retryLabel="Retry" />,
    );

    expect(getByText('Retry')).toBeOnTheScreen();
    expect(queryByText('Try again')).toBeNull();
  });
});
