/// Ports `flutter_app/test/error_reporter_test.dart` (issue #351).
import { ErrorReporting, LoggingErrorReporter, NoopErrorReporter, type ErrorReporter } from './error-reporter';

describe('ErrorReporting', () => {
  let original: ErrorReporter;

  beforeEach(() => {
    original = ErrorReporting.instance;
  });

  afterEach(() => {
    // Every global error hook and call site reads `ErrorReporting.instance`
    // fresh each time (see configure-error-reporting.ts / error-boundary.tsx),
    // so restoring it after each test keeps this suite from leaking a fake
    // reporter into unrelated tests.
    ErrorReporting.instance = original;
  });

  it('defaults to a LoggingErrorReporter', () => {
    expect(ErrorReporting.instance).toBeInstanceOf(LoggingErrorReporter);
  });

  it('instance is swappable, so a real SDK can replace it in one place', () => {
    const reported: { error: unknown; stack: string | undefined; context: string | undefined }[] = [];
    class FakeErrorReporter implements ErrorReporter {
      reportError(error: unknown, stack?: string, context?: string): void {
        reported.push({ error, stack, context });
      }
    }
    ErrorReporting.instance = new FakeErrorReporter();

    const error = new Error('boom');
    const stack = error.stack;
    ErrorReporting.instance.reportError(error, stack, 'test');

    expect(reported).toHaveLength(1);
    expect(reported[0]).toEqual({ error, stack, context: 'test' });
  });

  it('LoggingErrorReporter.reportError does not throw', () => {
    // console.error itself is the behavior under test here; silence it so
    // this test doesn't also print to the test run's own output, the same
    // way the Dart test relies on dart:developer's log() running without
    // throwing rather than asserting on captured output.
    const consoleError = jest.spyOn(console, 'error').mockImplementation(() => {});
    const reporter = new LoggingErrorReporter();

    expect(() => reporter.reportError(new Error('boom'))).not.toThrow();
    expect(() => reporter.reportError(new Error('boom'), undefined, 'unit-test')).not.toThrow();

    consoleError.mockRestore();
  });

  it('NoopErrorReporter.reportError does not throw and reports nothing', () => {
    const reporter: ErrorReporter = new NoopErrorReporter();
    expect(() => reporter.reportError(new Error('boom'), 'stack', 'context')).not.toThrow();
  });
});
