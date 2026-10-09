/**
 * SDK-independent abstraction point for reporting an otherwise-unhandled
 * error (issue #351, porting
 * `flutter_app/lib/platform/error_reporting/error_reporter.dart` from issue
 * #40/#287). Every global error hook this app installs (the root
 * `ErrorBoundary` in `error-boundary.tsx`, and any future
 * `global.ErrorUtils.setGlobalHandler` override / unhandled-promise-rejection
 * handler) and any call site that would otherwise silently swallow an error
 * (e.g. a bare `catch`) should route through {@link ErrorReporting.instance}
 * instead of logging directly. A Firebase Crashlytics-backed implementation
 * (`CrashlyticsErrorReporter` in `crashlytics-error-reporter.ts`) replaces
 * {@link ErrorReporting.instance} during app startup (see
 * `configure-error-reporting.ts`) -- no call site above needs to know which
 * implementation is active.
 *
 * `stack` mirrors Dart's `StackTrace` as a plain string (JS's
 * `Error.prototype.stack`), and is optional because not every thrown value
 * in JS is an `Error` with a stack (e.g. `throw 'boom'`).
 */
export interface ErrorReporter {
  /**
   * Reports `error` with its `stack`. `context` is a short, free-form label
   * describing where the error was caught (e.g. `'ErrorBoundary'`,
   * `'ProfileScreen.loadProfile'`) to make reports easier to triage.
   */
  reportError(error: unknown, stack?: string, context?: string): void;
}

/**
 * Default {@link ErrorReporter}, and what development builds keep -- see
 * {@link ErrorReporting}'s doc comment. Logs via `console.error`, which
 * stays visible in Metro's terminal output and the in-app LogBox during
 * development.
 */
export class LoggingErrorReporter implements ErrorReporter {
  reportError(error: unknown, stack?: string, context?: string): void {
    const label = context === undefined ? 'Unhandled error' : `Unhandled error: ${context}`;
    console.error(label, error, stack);
  }
}

/**
 * An {@link ErrorReporter} that does nothing, for tests and any environment
 * where reporting would be unwanted (e.g. so a test asserting an error
 * boundary renders its fallback UI doesn't also spam the test output or
 * require a real/fake Crashlytics client).
 */
export class NoopErrorReporter implements ErrorReporter {
  reportError(): void {
    // Intentionally does nothing.
  }
}

/**
 * Process-wide {@link ErrorReporter} access point. Defaults to
 * {@link LoggingErrorReporter}; `configure-error-reporting.ts` swaps
 * {@link instance} for a Crashlytics-backed implementation at app startup
 * instead of touching every call site that reports an error.
 */
export class ErrorReporting {
  private constructor() {}

  /**
   * The process-wide reporter, kept for every call site that reports an
   * error without its own injected {@link ErrorReporter}. New code that can
   * take a constructor/prop dependency should prefer that instead -- it
   * resolves to the exact same object in production, just explicitly rather
   * than through a global.
   */
  static instance: ErrorReporter = new LoggingErrorReporter();
}
