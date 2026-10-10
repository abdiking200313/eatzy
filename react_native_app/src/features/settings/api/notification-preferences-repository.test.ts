/**
 * Ports `flutter_app/test/notification_preferences_repository_test.dart`
 * (issue #401 / P8-05). `InMemorySharedPreferencesAsync` becomes an
 * in-memory `KeyValueStore` injected into
 * {@link AsyncStorageNotificationPreferencesStorage}.
 */
import type { KeyValueStore } from '@/stores/cart-storage';

import {
  AsyncStorageNotificationPreferencesStorage,
  DEFAULT_NOTIFICATION_PREFERENCES,
  notificationPreferencesFromJson,
  notificationPreferencesToJson,
  type NotificationPreferences,
} from './notification-preferences-repository';

function createInMemoryKeyValueStore(initial: Record<string, string> = {}): KeyValueStore & { data: Map<string, string> } {
  const data = new Map(Object.entries(initial));
  return {
    data,
    getItem: async (key) => data.get(key) ?? null,
    setItem: async (key, value) => {
      data.set(key, value);
    },
    removeItem: async (key) => {
      data.delete(key);
    },
  };
}

describe('NotificationPreferences', () => {
  test('copyWith changes only the given field', () => {
    const original = DEFAULT_NOTIFICATION_PREFERENCES;
    const updated: NotificationPreferences = { ...original, pushNotifications: false };

    expect(updated.pushNotifications).toBe(false);
    expect(updated.emailNotifications).toBe(original.emailNotifications);
    expect(updated.promotionalEmails).toBe(original.promotionalEmails);
    expect(updated.orderUpdates).toBe(original.orderUpdates);
  });

  test('round-trips through JSON', () => {
    const preferences: NotificationPreferences = {
      pushNotifications: false,
      emailNotifications: true,
      promotionalEmails: false,
      orderUpdates: true,
    };

    const restored = notificationPreferencesFromJson(
      JSON.parse(JSON.stringify(notificationPreferencesToJson(preferences))) as Record<string, unknown>,
    );

    expect(restored).toEqual(preferences);
  });

  test('missing JSON fields fall back to the defaults', () => {
    expect(notificationPreferencesFromJson({ emailNotifications: true })).toEqual({
      ...DEFAULT_NOTIFICATION_PREFERENCES,
      emailNotifications: true,
    });
  });
});

describe('AsyncStorageNotificationPreferencesStorage', () => {
  test('no saved value returns the documented defaults', async () => {
    const storage = new AsyncStorageNotificationPreferencesStorage(createInMemoryKeyValueStore());

    const result = await storage.read('owner-1');

    expect(result.pushNotifications).toBe(DEFAULT_NOTIFICATION_PREFERENCES.pushNotifications);
    expect(result.emailNotifications).toBe(DEFAULT_NOTIFICATION_PREFERENCES.emailNotifications);
  });

  test('a write is read back for the same owner', async () => {
    const storage = new AsyncStorageNotificationPreferencesStorage(createInMemoryKeyValueStore());

    await storage.write('owner-1', {
      pushNotifications: false,
      emailNotifications: true,
      promotionalEmails: false,
      orderUpdates: false,
    });
    const result = await storage.read('owner-1');

    expect(result.pushNotifications).toBe(false);
    expect(result.emailNotifications).toBe(true);
    expect(result.promotionalEmails).toBe(false);
    expect(result.orderUpdates).toBe(false);
  });

  test('writes under the same per-owner key as Flutter', async () => {
    const kv = createInMemoryKeyValueStore();
    const storage = new AsyncStorageNotificationPreferencesStorage(kv);

    await storage.write('owner-1', DEFAULT_NOTIFICATION_PREFERENCES);

    expect([...kv.data.keys()]).toEqual(['settings.notification_preferences.owner-1']);
  });

  test("different owners never see each other's preferences", async () => {
    const storage = new AsyncStorageNotificationPreferencesStorage(createInMemoryKeyValueStore());

    await storage.write('owner-1', { ...DEFAULT_NOTIFICATION_PREFERENCES, pushNotifications: false });

    const ownerTwoResult = await storage.read('owner-2');

    expect(ownerTwoResult.pushNotifications).toBe(DEFAULT_NOTIFICATION_PREFERENCES.pushNotifications);
  });

  test('a corrupted saved value is discarded rather than crashing the read', async () => {
    const kv = createInMemoryKeyValueStore({ 'settings.notification_preferences.owner-1': 'not valid json' });
    const storage = new AsyncStorageNotificationPreferencesStorage(kv);

    const result = await storage.read('owner-1');

    expect(result.pushNotifications).toBe(DEFAULT_NOTIFICATION_PREFERENCES.pushNotifications);
    expect(kv.data.has('settings.notification_preferences.owner-1')).toBe(false);
  });

  test('a non-map or wrongly typed saved value is also discarded', async () => {
    const kv = createInMemoryKeyValueStore({
      'settings.notification_preferences.owner-1': '[true]',
      'settings.notification_preferences.owner-2': JSON.stringify({ pushNotifications: 'yes' }),
    });
    const storage = new AsyncStorageNotificationPreferencesStorage(kv);

    expect(await storage.read('owner-1')).toEqual(DEFAULT_NOTIFICATION_PREFERENCES);
    expect(await storage.read('owner-2')).toEqual(DEFAULT_NOTIFICATION_PREFERENCES);
    expect(kv.data.size).toBe(0);
  });
});
