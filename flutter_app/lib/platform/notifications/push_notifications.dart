import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// SDK-independent abstraction over Firebase Cloud Messaging (issue #47),
/// mirroring how [ErrorReporter]
/// (`lib/platform/error_reporting/error_reporter.dart`) wraps its own SDK
/// choice: call sites (startup, the Settings notification toggle) depend on
/// this interface, not on `firebase_messaging` directly, so tests can inject
/// a fake instead of needing a real Firebase app and platform channels.
abstract interface class PushNotificationGateway {
  /// Sets up the underlying push SDK. Safe to call more than once. Must run
  /// before [requestPermission] or [hasPermission].
  Future<void> initialize();

  /// Prompts the user for notification permission if it hasn't already been
  /// decided, returning whether push notifications are now allowed. On
  /// Android this is what actually shows the system permission dialog (API
  /// 33+); on an earlier Android version permission is implicitly granted at
  /// install time and this returns `true` without prompting.
  Future<bool> requestPermission();

  /// Reads the current permission status without prompting the user.
  Future<bool> hasPermission();
}

/// Real [PushNotificationGateway] backed by `firebase_core` +
/// `firebase_messaging`, reading `android/app/google-services.json` (Firebase
/// project `zivo-41908`).
///
/// **Android only** (issue #47's explicit scope): the owner has no Apple
/// Developer account yet, so `ios/Runner/GoogleService-Info.plist` is
/// committed but stays unwired (not referenced by
/// `ios/Runner.xcodeproj/project.pbxproj`) until #55 resolves that. Every
/// method below no-ops on any platform other than Android rather than
/// touching the Firebase SDK at all, so nothing here reaches for the
/// unwired iOS config.
class FirebaseMessagingGateway implements PushNotificationGateway {
  const FirebaseMessagingGateway();

  bool get _supportsPush =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> initialize() async {
    if (!_supportsPush) return;
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_supportsPush) return false;
    final settings = await FirebaseMessaging.instance.requestPermission();
    return _isGranted(settings.authorizationStatus);
  }

  @override
  Future<bool> hasPermission() async {
    if (!_supportsPush) return false;
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return _isGranted(settings.authorizationStatus);
  }

  bool _isGranted(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;
}

/// Process-wide [PushNotificationGateway] access point, following
/// [ErrorReporting]'s pattern. Defaults to [FirebaseMessagingGateway];
/// swappable in tests.
class PushNotifications {
  PushNotifications._();

  static PushNotificationGateway instance = const FirebaseMessagingGateway();
}
