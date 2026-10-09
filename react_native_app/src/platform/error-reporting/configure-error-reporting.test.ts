/// Covers this issue's "falls back to LoggingErrorReporter when the native
/// module is unavailable" acceptance criterion (issue #351) -- not a direct
/// port, since the Flutter app's equivalent wiring
/// (`lib/platform/startup/startup_gate.dart`) is exercised through its own
/// startup-sequence tests rather than a standalone unit test.
import { configureErrorReporting } from './configure-error-reporting';
import { ErrorReporting, LoggingErrorReporter, type ErrorReporter } from './error-reporter';

describe('configureErrorReporting', () => {
  let original: ErrorReporter;
  let consoleWarn: jest.SpyInstance;

  beforeEach(() => {
    original = ErrorReporting.instance;
    consoleWarn = jest.spyOn(console, 'warn').mockImplementation(() => {});
  });

  afterEach(() => {
    ErrorReporting.instance = original;
    consoleWarn.mockRestore();
  });

  it('does not throw, and falls back to the default LoggingErrorReporter when the native Crashlytics module is unavailable (e.g. under Jest/Expo Go)', async () => {
    await expect(configureErrorReporting()).resolves.toBeUndefined();
    expect(ErrorReporting.instance).toBeInstanceOf(LoggingErrorReporter);
  });
});
