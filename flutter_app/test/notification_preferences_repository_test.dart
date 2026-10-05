import 'package:chowflow/features/settings/data/notification_preferences_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  group('NotificationPreferences', () {
    test('copyWith changes only the given field', () {
      const original = NotificationPreferences.defaults;
      final updated = original.copyWith(pushNotifications: false);

      expect(updated.pushNotifications, isFalse);
      expect(updated.emailNotifications, original.emailNotifications);
      expect(updated.promotionalEmails, original.promotionalEmails);
      expect(updated.orderUpdates, original.orderUpdates);
    });

    test('round-trips through JSON', () {
      const preferences = NotificationPreferences(
        pushNotifications: false,
        emailNotifications: true,
        promotionalEmails: false,
        orderUpdates: true,
      );

      final restored = NotificationPreferences.fromJson(preferences.toJson());

      expect(restored.pushNotifications, preferences.pushNotifications);
      expect(restored.emailNotifications, preferences.emailNotifications);
      expect(restored.promotionalEmails, preferences.promotionalEmails);
      expect(restored.orderUpdates, preferences.orderUpdates);
    });
  });

  group('SharedPreferencesNotificationPreferencesStorage', () {
    test('no saved value returns the documented defaults', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final storage = SharedPreferencesNotificationPreferencesStorage();

      final result = await storage.read('owner-1');

      expect(
        result.pushNotifications,
        NotificationPreferences.defaults.pushNotifications,
      );
      expect(
        result.emailNotifications,
        NotificationPreferences.defaults.emailNotifications,
      );
    });

    test('a write is read back for the same owner', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final storage = SharedPreferencesNotificationPreferencesStorage();
      const preferences = NotificationPreferences(
        pushNotifications: false,
        emailNotifications: true,
        promotionalEmails: false,
        orderUpdates: false,
      );

      await storage.write('owner-1', preferences);
      final result = await storage.read('owner-1');

      expect(result.pushNotifications, isFalse);
      expect(result.emailNotifications, isTrue);
      expect(result.promotionalEmails, isFalse);
      expect(result.orderUpdates, isFalse);
    });

    test('different owners never see each other\'s preferences', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final storage = SharedPreferencesNotificationPreferencesStorage();

      await storage.write(
        'owner-1',
        NotificationPreferences.defaults.copyWith(pushNotifications: false),
      );

      final ownerTwoResult = await storage.read('owner-2');

      expect(
        ownerTwoResult.pushNotifications,
        NotificationPreferences.defaults.pushNotifications,
      );
    });

    test(
      'a corrupted saved value is discarded rather than crashing the read',
      () async {
        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.withData({
              'settings.notification_preferences.owner-1': 'not valid json',
            });
        final storage = SharedPreferencesNotificationPreferencesStorage();

        final result = await storage.read('owner-1');

        expect(
          result.pushNotifications,
          NotificationPreferences.defaults.pushNotifications,
        );
      },
    );
  });
}
