import 'package:chowflow/platform/notifications/push_notifications.dart';

/// A [PushNotificationGateway] test double that never touches the real
/// Firebase SDK, so settings-screen tests can drive both the granted and
/// denied permission paths without a platform channel.
class FakePushNotificationGateway implements PushNotificationGateway {
  FakePushNotificationGateway({bool granted = true}) : _granted = granted;

  bool _granted;
  int requestPermissionCallCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async {
    requestPermissionCallCount++;
    return _granted;
  }

  @override
  Future<bool> hasPermission() async => _granted;

  /// Lets a test simulate the user granting/denying/revoking permission
  /// outside the app between calls.
  void setGranted(bool granted) => _granted = granted;
}
