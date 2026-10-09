/**
 * Ports `flutter_app/lib/platform/error_reporting/crashlytics_error_reporter.dart`
 * (issue #287) to this app (issue #351).
 */
import type { ErrorReporter } from './error-reporter';

/**
 * Thin wrapper over `@react-native-firebase/crashlytics`: {@link CrashlyticsErrorReporter}
 * depends on this interface, not on the SDK directly, so it can be unit
 * tested with a fake instead of needing a real Firebase app and native
 * modules (mirrors how `CrashlyticsClient` is used in the Flutter port).
 */
export interface CrashlyticsClient {
  /**
   * Records `error`/`stack` with the underlying SDK. `fatal` marks the
   * report as a crash (counts against crash-free-users in the Firebase
   * console) rather than a handled/non-fatal error. `reason` is a short
   * free-form label describing where the error came from.
   *
   * Unlike the Flutter `firebase_crashlytics` plugin, the underlying
   * `@react-native-firebase/crashlytics` JS API has no `fatal` parameter on
   * its own `recordError` -- there is no JS-callable way to mark a
   * *recorded* (non-crashing) error as a crash; Crashlytics' crash-free-users
   * metric is otherwise reserved for actual native crashes. `fatal` is still
   * tracked through this interface, and the real implementation
   * ({@link FirebaseCrashlyticsClient}) surfaces it the best way the SDK
   * allows (see its doc comment) rather than dropping the distinction.
   */
  recordError(
    error: unknown,
    stack: string | undefined,
    options?: { fatal?: boolean; reason?: string },
  ): Promise<void>;

  /**
   * Sets the Crashlytics user identifier (no email/name -- only ever the
   * Supabase auth user id, same restriction as the Flutter app). Pass an
   * empty string to clear it on sign-out, per Crashlytics' own API (there is
   * no dedicated "clear" method).
   */
  setUserIdentifier(identifier: string): Promise<void>;

  /**
   * Enables or disables report collection. Called once during startup (see
   * `configure-error-reporting.ts`).
   */
  setCrashlyticsCollectionEnabled(enabled: boolean): Promise<void>;
}

/** Builds a real `Error` (required by the native SDK) out of an arbitrary thrown value and an optional stack override. */
function toJsError(error: unknown, stack: string | undefined): Error {
  const jsError = error instanceof Error ? error : new Error(String(error));
  if (stack !== undefined && jsError.stack !== stack) {
    jsError.stack = stack;
  }
  return jsError;
}

/** {@link CrashlyticsClient} backed by the real `@react-native-firebase/crashlytics` SDK. */
export class FirebaseCrashlyticsClient implements CrashlyticsClient {
  async recordError(
    error: unknown,
    stack: string | undefined,
    { fatal = false, reason }: { fatal?: boolean; reason?: string } = {},
  ): Promise<void> {
    // Lazily imported so this module has no load-time dependency on native
    // Firebase modules -- importing it only when a real report is recorded
    // keeps `NoopErrorReporter`/`LoggingErrorReporter` builds (development
    // without a native module available, and any test that never constructs
    // this class) free of a native-module requirement.
    const { getApp } = await import('@react-native-firebase/app');
    const { getCrashlytics, log, recordError } = await import('@react-native-firebase/crashlytics');

    const instance = getCrashlytics(getApp());
    const jsError = toJsError(error, stack);

    // See this interface's doc comment: there's no `fatal` flag on the
    // SDK's own `recordError`, so it's logged as a breadcrumb immediately
    // before the report -- visible on the report's log tab in the Firebase
    // console.
    log(instance, fatal ? `[fatal${reason ? `: ${reason}` : ''}]` : `[non-fatal${reason ? `: ${reason}` : ''}]`);
    await recordError(instance, jsError, reason);
  }

  async setUserIdentifier(identifier: string): Promise<void> {
    const { getApp } = await import('@react-native-firebase/app');
    const { getCrashlytics, setUserId } = await import('@react-native-firebase/crashlytics');
    await setUserId(getCrashlytics(getApp()), identifier);
  }

  async setCrashlyticsCollectionEnabled(enabled: boolean): Promise<void> {
    const { getApp } = await import('@react-native-firebase/app');
    const { getCrashlytics, setCrashlyticsCollectionEnabled } = await import('@react-native-firebase/crashlytics');
    await setCrashlyticsCollectionEnabled(getCrashlytics(getApp()), enabled);
  }
}

/**
 * {@link ErrorReporter} backed by Firebase Crashlytics (issue #351, porting
 * issue #287's Flutter implementation). Assigned to `ErrorReporting.instance`
 * during app startup by `configure-error-reporting.ts`, which falls back to
 * (and leaves in place) the default `LoggingErrorReporter` when the native
 * module isn't available (e.g. Expo Go).
 *
 * An error is recorded **fatal** when `context` is one of the global error
 * hooks the app installs -- currently just `'ErrorBoundary'`
 * (`error-boundary.tsx`, issue #351): a render error caught there would
 * otherwise have blanked the whole app with no `catch` in between. Every
 * other call site already caught the error itself before calling
 * `reportError`, so those are reported non-fatal -- the app kept running,
 * just degraded. Mirrors `CrashlyticsErrorReporter.globalHookContexts` in
 * the Flutter port (which lists `FlutterError`/`PlatformDispatcher`/
 * `runZonedGuarded` -- this app's equivalent global JS error/unhandled-
 * rejection hooks aren't wired up yet; add their context labels here when
 * they are).
 */
export class CrashlyticsErrorReporter implements ErrorReporter {
  constructor(private readonly client: CrashlyticsClient) {}

  static readonly globalHookContexts: ReadonlySet<string> = new Set(['ErrorBoundary']);

  reportError(error: unknown, stack?: string, context?: string): void {
    const fatal = context !== undefined && CrashlyticsErrorReporter.globalHookContexts.has(context);
    // ErrorReporter.reportError is synchronous/void (every call site,
    // including the global hooks, calls it fire-and-forget -- see
    // LoggingErrorReporter), so the underlying native-module call is not
    // awaited here either.
    void this.client.recordError(error, stack, { fatal, reason: context });
  }

  /**
   * Sets the Crashlytics user identifier to `userId`, or clears it when
   * `userId` is `null`/`undefined` (sign-out). No email or name should ever
   * be passed here, only the Supabase auth user id.
   */
  setUserIdentifier(userId: string | null | undefined): Promise<void> {
    return this.client.setUserIdentifier(userId ?? '');
  }
}
