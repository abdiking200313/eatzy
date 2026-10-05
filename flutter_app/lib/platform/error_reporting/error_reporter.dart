import 'dart:developer' as developer;

/// SDK-independent abstraction point for reporting an otherwise-unhandled
/// error (issue #40). Every global error hook (`FlutterError.onError`,
/// `PlatformDispatcher.instance.onError`, the `runZonedGuarded` error
/// callback in `main.dart`) and any call site that would previously have
/// silently swallowed an error (e.g. a `catch (Object)` block) should route
/// through [ErrorReporting.instance] instead of logging directly. Issue #287
/// wired in a Firebase Crashlytics-backed implementation
/// (`CrashlyticsErrorReporter` in `crashlytics_error_reporter.dart`),
/// assigned to [ErrorReporting.instance] from `runStartupSequence`
/// (`lib/platform/startup/startup_gate.dart`) in release/profile builds
/// only -- no call site above had to change.
abstract class ErrorReporter {
  /// Reports [error] with its [stack]. [context] is a short, free-form label
  /// describing where the error was caught (e.g. `'FlutterError'`,
  /// `'ProfileScreen._loadProfile'`) to make reports easier to triage.
  void reportError(Object error, StackTrace stack, {String? context});
}

/// Default [ErrorReporter], and what debug builds keep even after #287 --
/// see `CrashlyticsErrorReporter`'s doc comment. Logs via `dart:developer`'s
/// [developer.log], which — unlike
/// `debugPrint` — is not a no-op in release builds and remains visible via
/// `flutter logs` / `adb logcat` / Xcode's console after release.
class LoggingErrorReporter implements ErrorReporter {
  const LoggingErrorReporter();

  @override
  void reportError(Object error, StackTrace stack, {String? context}) {
    developer.log(
      context == null ? 'Unhandled error' : 'Unhandled error: $context',
      name: 'zivo.errors',
      error: error,
      stackTrace: stack,
      // SEVERE, so it stands out among ordinary log-level output.
      level: 1000,
    );
  }
}

/// Process-wide [ErrorReporter] access point. Defaults to
/// [LoggingErrorReporter]; `runStartupSequence` swaps [instance] for a
/// Crashlytics-backed implementation in release/profile builds (issue #287)
/// instead of touching every call site that reports an error.
class ErrorReporting {
  ErrorReporting._();

  /// Process-wide reporter, kept for every call site that hasn't migrated
  /// yet (including every global error hook in `main.dart`, which runs
  /// before the composition root exists). New code with a [BuildContext]
  /// should prefer `AppScope.of(context).errorReporter`
  /// (`lib/app/app_scope.dart`, issue #281) instead of reaching for this
  /// directly -- it resolves to the exact same object in production, just
  /// through the app's composition root rather than a global.
  static ErrorReporter instance = const LoggingErrorReporter();
}
