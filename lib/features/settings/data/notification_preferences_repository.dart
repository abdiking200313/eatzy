import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The 4 notification toggles shown on the Settings screen.
///
/// Immutable so callers always persist (and render) a complete, consistent
/// set of preferences rather than one changed field at a time.
class NotificationPreferences {
  const NotificationPreferences({
    required this.pushNotifications,
    required this.emailNotifications,
    required this.promotionalEmails,
    required this.orderUpdates,
  });

  /// Starting values shown before any preference has ever been saved for
  /// the signed-in owner. Matches the screen's previous hardcoded defaults
  /// so existing users see no visible change until they flip a toggle.
  static const defaults = NotificationPreferences(
    pushNotifications: true,
    emailNotifications: false,
    promotionalEmails: true,
    orderUpdates: true,
  );

  final bool pushNotifications;
  final bool emailNotifications;
  final bool promotionalEmails;
  final bool orderUpdates;

  NotificationPreferences copyWith({
    bool? pushNotifications,
    bool? emailNotifications,
    bool? promotionalEmails,
    bool? orderUpdates,
  }) {
    return NotificationPreferences(
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      promotionalEmails: promotionalEmails ?? this.promotionalEmails,
      orderUpdates: orderUpdates ?? this.orderUpdates,
    );
  }

  Map<String, dynamic> toJson() => {
    'pushNotifications': pushNotifications,
    'emailNotifications': emailNotifications,
    'promotionalEmails': promotionalEmails,
    'orderUpdates': orderUpdates,
  };

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      pushNotifications:
          json['pushNotifications'] as bool? ?? defaults.pushNotifications,
      emailNotifications:
          json['emailNotifications'] as bool? ?? defaults.emailNotifications,
      promotionalEmails:
          json['promotionalEmails'] as bool? ?? defaults.promotionalEmails,
      orderUpdates: json['orderUpdates'] as bool? ?? defaults.orderUpdates,
    );
  }
}

/// Reads and writes [NotificationPreferences] for one signed-in owner.
///
/// Scoped by `ownerId` — like [CartStorage] in
/// `lib/services/shared/data/cart_storage.dart` — so switching accounts (or
/// being signed out) on the same device never leaks one owner's
/// notification preferences into another's.
abstract interface class NotificationPreferencesStorage {
  Future<NotificationPreferences> read(String ownerId);

  Future<void> write(String ownerId, NotificationPreferences preferences);
}

/// A [NotificationPreferencesStorage] backed by [SharedPreferencesAsync],
/// serialized as JSON under the key `$_keyPrefix.$ownerId` — mirroring
/// [SharedPreferencesCartStorage]'s persistence shape.
class SharedPreferencesNotificationPreferencesStorage
    implements NotificationPreferencesStorage {
  static const _keyPrefix = 'settings.notification_preferences';

  String _keyFor(String ownerId) => '$_keyPrefix.$ownerId';

  SharedPreferencesAsync get _preferences => SharedPreferencesAsync();

  @override
  Future<NotificationPreferences> read(String ownerId) async {
    final key = _keyFor(ownerId);
    final raw = await _preferences.getString(key);
    if (raw == null || raw.isEmpty) {
      return NotificationPreferences.defaults;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('Notification preferences must be a map');
      }
      return NotificationPreferences.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } on Object {
      // A broken local value should not make the settings screen unusable.
      await _preferences.remove(key);
      return NotificationPreferences.defaults;
    }
  }

  @override
  Future<void> write(String ownerId, NotificationPreferences preferences) {
    return _preferences.setString(
      _keyFor(ownerId),
      jsonEncode(preferences.toJson()),
    );
  }
}
