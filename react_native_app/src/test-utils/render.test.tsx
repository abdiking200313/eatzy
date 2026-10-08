import { useQuery } from '@tanstack/react-query';
import { screen, waitFor } from '@testing-library/react-native';

import { ThemedText } from '@/components/themed-text';

import { createTestQueryClient, renderWithProviders } from './render';

describe('renderWithProviders', () => {
  it('renders an existing component', async () => {
    await renderWithProviders(<ThemedText>Hello, Zivo</ThemedText>);

    expect(screen.getByText('Hello, Zivo')).toBeTruthy();
  });

  it('provides a QueryClientProvider so a useQuery call resolves instead of throwing', async () => {
    function ComponentUsingQuery() {
      const { data } = useQuery({ queryKey: ['greeting'], queryFn: () => 'from a query' });
      return <ThemedText>{data ?? 'loading'}</ThemedText>;
    }

    await renderWithProviders(<ComponentUsingQuery />);

    await waitFor(() => expect(screen.getByText('from a query')).toBeTruthy());
  });

  it('builds a fresh QueryClient per render by default, so renders never share cache state', async () => {
    const first = await renderWithProviders(<ThemedText>first</ThemedText>);
    const second = await renderWithProviders(<ThemedText>second</ThemedText>);

    expect(first.queryClient).not.toBe(second.queryClient);
  });

  it('accepts a caller-supplied QueryClient, e.g. one pre-populated via setQueryData', async () => {
    const queryClient = createTestQueryClient();
    queryClient.setQueryData(['greeting'], 'pre-seeded');

    function ComponentReadingCache() {
      const { data } = useQuery({ queryKey: ['greeting'], queryFn: () => 'should not run' });
      return <ThemedText>{data}</ThemedText>;
    }

    await renderWithProviders(<ComponentReadingCache />, { queryClient });

    expect(screen.getByText('pre-seeded')).toBeTruthy();
  });
});
