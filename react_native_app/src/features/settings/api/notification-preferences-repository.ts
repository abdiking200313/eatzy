/**
 * Ports `flutter_app/lib/features/settings/data/notification_preferences_repository.dart`
 * (issue #401 / P8-05): the four notification toggles shown on the Settings
 * screen, persisted locally per signed-in owner.
 *
 * `@react-native-async-storage/async-storage` stands in for Dart's
 * `SharedPreferencesAsync`, exactly as `cart-storage.ts` does -- these are
 * non-sensitive, local-only flags. The key shape
 * (`settings.notification_preferences.<ownerId>`) and JSON field names
 * match Flutter's.
 */
import AsyncStorage from '@react-native-async-storage/async-storage';

import type { KeyValueStore } from '@/stores/cart-storage';

/** Ports the immutable Dart `NotificationPreferences`. */
export type NotificationPreferences = Readonly<{
  pushNotifications: boolean;
  emailNotifications: boolean;
  promotionalEmails: boolean;
  orderUpdates: boolean;
}>;

/**
 * Starting values shown before any preference has ever been saved for the
 * signed-in owner. Mirrors `NotificationPreferences.defaults`.
 */
export const DEFAULT_NOTIFICATION_PREFERENCES: NotificationPreferences = Object.freeze({
  pushNotifications: true,
  emailNotifications: false,
  promotionalEmails: true,
  orderUpdates: true,
});

/** Mirrors `NotificationPreferences.toJson`. */
export function notificationPreferencesToJson(preferences: NotificationPreferences): Record<string, boolean> {
  return {
    pushNotifications: preferences.pushNotifications,
    emailNotifications: preferences.emailNotifications,
    promotionalEmails: preferences.promotionalEmails,
    orderUpdates: preferences.orderUpdates,
  };
}

/**
 * Mirrors `NotificationPreferences.fromJson`: a missing field falls back to
 * its default. Dart's `as bool?` throws on a present non-bool value; that is
 * mirrored here so a malformed stored value is discarded by
 * {@link AsyncStorageNotificationPreferencesStorage.read} rather than coerced.
 */
export function notificationPreferencesFromJson(json: Record<string, unknown>): NotificationPreferences {
  const field = (key: keyof NotificationPreferences): boolean => {
    const value = json[key];
    if (value == null) return DEFAULT_NOTIFICATION_PREFERENCES[key];
    if (typeof value !== 'boolean') throw new TypeError(`Notification preference "${key}" must be a boolean`);
    return value;
  };
  return {
    pushNotifications: field('pushNotifications'),
    emailNotifications: field('emailNotifications'),
    promotionalEmails: field('promotionalEmails'),
    orderUpdates: field('orderUpdates'),
  };
}

/**
 * Ports `NotificationPreferencesStorage`: reads and writes preferences for
 * one owner, scoped by `ownerId` so switching accounts on the same device
 * never leaks one owner's preferences into another's.
 */
export interface NotificationPreferencesStorage {
  read(ownerId: string): Promise<NotificationPreferences>;
  write(ownerId: string, preferences: NotificationPreferences): Promise<void>;
}

/** Mirrors `SharedPreferencesNotificationPreferencesStorage._keyPrefix`. */
export const NOTIFICATION_PREFERENCES_KEY_PREFIX = 'settings.notification_preferences';

const defaultKeyValueStore: KeyValueStore = {
  getItem: (key) => AsyncStorage.getItem(key),
  setItem: (key, value) => AsyncStorage.setItem(key, value),
  removeItem: (key) => AsyncStorage.removeItem(key),
};

/** Ports `SharedPreferencesNotificationPreferencesStorage`. */
export class AsyncStorageNotificationPreferencesStorage implements NotificationPreferencesStorage {
  constructor(private readonly store: KeyValueStore = defaultKeyValueStore) {}

  private keyFor(ownerId: string): string {
    return `${NOTIFICATION_PREFERENCES_KEY_PREFIX}.${ownerId}`;
  }

  async read(ownerId: string): Promise<NotificationPreferences> {
    const key = this.keyFor(ownerId);
    const raw = await this.store.getItem(key);
    if (raw == null || raw === '') return DEFAULT_NOTIFICATION_PREFERENCES;

    try {
      const decoded: unknown = JSON.parse(raw);
      if (decoded == null || typeof decoded !== 'object' || Array.isArray(decoded)) {
        throw new TypeError('Notification preferences must be a map');
      }
      return notificationPreferencesFromJson(decoded as Record<string, unknown>);
    } catch {
      // A broken local value should not make the settings screen unusable.
      await this.store.removeItem(key);
      return DEFAULT_NOTIFICATION_PREFERENCES;
    }
  }

  write(ownerId: string, preferences: NotificationPreferences): Promise<void> {
    return this.store.setItem(this.keyFor(ownerId), JSON.stringify(notificationPreferencesToJson(preferences)));
  }
}
