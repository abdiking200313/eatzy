import 'package:chowflow/features/settings/data/notification_preferences_repository.dart';

/// An in-memory [NotificationPreferencesStorage] used by settings-screen
/// tests so persistence can be exercised without a real SharedPreferences
/// platform channel. Mirrors `MemoryCartStorage`.
class MemoryNotificationPreferencesStorage
    implements NotificationPreferencesStorage {
  final Map<String, NotificationPreferences> _saved = {};

  @override
  Future<NotificationPreferences> read(String ownerId) async {
    return _saved[ownerId] ?? NotificationPreferences.defaults;
  }

  @override
  Future<void> write(
    String ownerId,
    NotificationPreferences preferences,
  ) async {
    _saved[ownerId] = preferences;
  }
}
