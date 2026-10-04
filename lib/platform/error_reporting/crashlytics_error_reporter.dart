import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'error_reporter.dart';

/// Thin wrapper over [FirebaseCrashlytics] (issue #287), mirroring how
/// [PushNotificationGateway]
/// (`lib/platform/notifications/push_notifications.dart`) wraps
/// `firebase_messaging`: [CrashlyticsErrorReporter] depends on this
/// interface, not on `firebase_crashlytics` directly, so it can be unit
/// tested with a fake instead of needing a real Firebase app and platform
/// channels.
abstract interface class CrashlyticsClient {
  /// Records [exception]/[stack] with the underlying SDK. [fatal] marks the
  /// report as a crash (counts against crash-free-users in the Firebase
  /// console) rather than a handled/non-fatal error. [reason] is a short
  /// free-form label describing where the error came from.
  Future<void> recordError(
    Object exception,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  });

  /// Sets the Crashlytics user identifier (no email/name -- see
  /// `AccountStateCoordinator`/`main.dart`'s auth-state listener, which is
  /// the only caller). Pass an empty string to clear it on sign-out, per
  /// Crashlytics' own API (there is no dedicated "clear" method).
  Future<void> setUserIdentifier(String identifier);

  /// Enables or disables report collection. Called once during startup:
  /// enabled in release/profile builds, disabled in debug.
  Future<void> setCrashlyticsCollectionEnabled(bool enabled);
}

/// [CrashlyticsClient] backed by the real `firebase_crashlytics` SDK.
class FirebaseCrashlyticsClient implements CrashlyticsClient {
  const FirebaseCrashlyticsClient();

  FirebaseCrashlytics get _crashlytics => FirebaseCrashlytics.instance;

  @override
  Future<void> recordError(
    Object exception,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) {
    return _crashlytics.recordError(
      exception,
      stack,
      fatal: fatal,
      reason: reason,
    );
  }

  @override
  Future<void> setUserIdentifier(String identifier) =>
      _crashlytics.setUserIdentifier(identifier);

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) =>
      _crashlytics.setCrashlyticsCollectionEnabled(enabled);
}

/// [ErrorReporter] backed by Firebase Crashlytics (issue #287). Wired in as
/// [ErrorReporting.instance] from `runStartupSequence`
/// (`lib/platform/startup/startup_gate.dart`) in release/profile builds
/// only, once Firebase has been initialized -- debug builds keep
/// [LoggingErrorReporter] and explicitly disable collection instead.
///
/// An error is recorded **fatal** when [context] is one of the global error
/// hooks `main.dart` installs (`FlutterError`, `PlatformDispatcher`,
/// `runZonedGuarded`): those are genuinely-unhandled errors that would
/// otherwise have crashed the app with no `catch` in between. Every other
/// call site (e.g. `StartupGate`, `ProfileScreen._loadProfile`,
/// `CartController`) already caught the error itself before calling
/// [reportError], so those are reported non-fatal -- the app kept running,
/// just degraded.
class CrashlyticsErrorReporter implements ErrorReporter {
  const CrashlyticsErrorReporter(this._client);

  final CrashlyticsClient _client;

  /// The exact `context` strings `main.dart`'s global hooks pass -- see its
  /// own doc comment. Keep this set in sync if a hook's context label ever
  /// changes.
  static const Set<String> globalHookContexts = {
    'FlutterError',
    'PlatformDispatcher',
    'runZonedGuarded',
  };

  @override
  void reportError(Object error, StackTrace stack, {String? context}) {
    final fatal = context != null && globalHookContexts.contains(context);
    // ErrorReporter.reportError is synchronous/void (every call site,
    // including the global hooks, calls it fire-and-forget -- see
    // LoggingErrorReporter), so the underlying platform-channel call is not
    // awaited here either.
    unawaited(_client.recordError(error, stack, fatal: fatal, reason: context));
  }

  /// Sets the Crashlytics user identifier to [userId], or clears it when
  /// [userId] is `null` (sign-out) -- called from
  /// [AccountStateCoordinator.handleOwnerChanged]
  /// (`lib/platform/session/account_state_coordinator.dart`). No email or
  /// name is ever passed here, only the Supabase auth user id.
  Future<void> setUserIdentifier(String? userId) {
    return _client.setUserIdentifier(userId ?? '');
  }
}
