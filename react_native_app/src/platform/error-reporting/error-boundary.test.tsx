/// Component test for the root error boundary (issue #351) — not a direct
/// port (the Flutter app has no equivalent widget test for
/// `error_fallback.dart`), added to cover this issue's "a render error shows
/// the fallback screen" acceptance criterion.
import { Text } from 'react-native';

import { ErrorReporting, type ErrorReporter } from '@/platform/error-reporting/error-reporter';
import { renderWithProviders } from '@/test-utils';

import { ErrorBoundary } from './error-boundary';

function ThrowingChild(): never {
  throw new Error('boom');
}

describe('ErrorBoundary', () => {
  let original: ErrorReporter;
  let consoleError: jest.SpyInstance;

  beforeEach(() => {
    original = ErrorReporting.instance;
    // React logs a caught render error to console.error itself; silence it
    // so this *expected* error doesn't make the test run look like it
    // failed.
    consoleError = jest.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    ErrorReporting.instance = original;
    consoleError.mockRestore();
  });

  it('renders its children when nothing throws', async () => {
    const { getByText } = await renderWithProviders(
      <ErrorBoundary>
        <Text>All good</Text>
      </ErrorBoundary>,
    );

    expect(getByText('All good')).toBeOnTheScreen();
  });

  it('shows the fallback UI instead of a blank/crashed screen when a child throws', async () => {
    const { getByText } = await renderWithProviders(
      <ErrorBoundary>
        <ThrowingChild />
      </ErrorBoundary>,
    );

    expect(getByText('Something went wrong')).toBeOnTheScreen();
  });

  it('reports the error through ErrorReporting.instance with context "ErrorBoundary"', async () => {
    const reported: { error: unknown; context: string | undefined }[] = [];
    ErrorReporting.instance = {
      reportError: (error, _stack, context) => {
        reported.push({ error, context });
      },
    };

    await renderWithProviders(
      <ErrorBoundary>
        <ThrowingChild />
      </ErrorBoundary>,
    );

    expect(reported).toHaveLength(1);
    expect(reported[0].context).toBe('ErrorBoundary');
    expect((reported[0].error as Error).message).toBe('boom');
  });
});
