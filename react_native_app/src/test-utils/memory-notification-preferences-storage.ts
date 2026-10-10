/// Ports `flutter_app/test/helpers/memory_notification_preferences_storage.dart`
/// and `fake_push_notification_gateway.dart` (issue #401): in-memory test
/// doubles for the Settings screen's notification preferences and push
/// permission, so neither real `AsyncStorage` nor a push SDK is touched.
import {
  DEFAULT_NOTIFICATION_PREFERENCES,
  type NotificationPreferences,
  type NotificationPreferencesStorage,
} from '@/features/settings/api/notification-preferences-repository';
import type { PushNotificationGateway } from '@/platform/notifications/push-notifications';

export class MemoryNotificationPreferencesStorage implements NotificationPreferencesStorage {
  private readonly saved = new Map<string, NotificationPreferences>();

  async read(ownerId: string): Promise<NotificationPreferences> {
    return this.saved.get(ownerId) ?? DEFAULT_NOTIFICATION_PREFERENCES;
  }

  async write(ownerId: string, preferences: NotificationPreferences): Promise<void> {
    this.saved.set(ownerId, preferences);
  }
}

export class FakePushNotificationGateway implements PushNotificationGateway {
  requestPermissionCallCount = 0;

  constructor(private granted = true) {}

  async initialize(): Promise<void> {}

  async requestPermission(): Promise<boolean> {
    this.requestPermissionCallCount++;
    return this.granted;
  }

  async hasPermission(): Promise<boolean> {
    return this.granted;
  }

  /** Simulates the user granting/denying/revoking permission outside the app. */
  setGranted(granted: boolean): void {
    this.granted = granted;
  }
}
