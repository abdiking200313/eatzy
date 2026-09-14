import 'dart:developer' as developer;

/// SDK-independent abstraction point for reporting an otherwise-unhandled
/// error (issue #40). Every global error hook (`FlutterError.onError`,
/// `PlatformDispatcher.instance.onError`, the `runZonedGuarded` error
/// callback in `main.dart`) and any call site that would previously have
/// silently swallowed an error (e.g. a `catch (Object)` block) should route
/// through [ErrorReporting.instance] instead of logging directly, so wiring
/// in a real crash-reporting SDK later (Firebase Crashlytics — deferred
/// fast-follow once the owner supplies `google-services.json` /
/// `GoogleService-Info.plist`) is a one-place change: replace the
/// [ErrorReporter] assigned to [ErrorReporting.instance] with a
/// Crashlytics-backed implementation, no call sites change.
abstract class ErrorReporter {
  /// Reports [error] with its [stack]. [context] is a short, free-form label
  /// describing where the error was caught (e.g. `'FlutterError'`,
  /// `'ProfileScreen._loadProfile'`) to make reports easier to triage.
  void reportError(Object error, StackTrace stack, {String? context});
}

/// Default [ErrorReporter] used until a real crash-reporting SDK is wired
/// in. Logs via `dart:developer`'s [developer.log], which — unlike
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
/// [LoggingErrorReporter]; a future Crashlytics fast-follow swaps
/// [instance] for a Crashlytics-backed implementation during app startup
/// instead of touching every call site that reports an error.
class ErrorReporting {
  ErrorReporting._();

  static ErrorReporter instance = const LoggingErrorReporter();
}
