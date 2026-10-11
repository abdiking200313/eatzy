/**
 * Ports `flutter_app/lib/platform/notifications/push_notifications.dart`:
 * the `PushNotificationGateway` seam (added by #401 / P8-05 for the Settings
 * "Push Notifications" toggle), the real SDK-backed gateway (#405 / P8-10),
 * and the `PushNotifications` access point.
 *
 * Like the Flutter app, this only asks for permission -- it does not fetch
 * or store a device token and does not receive pushes yet.
 *
 * ## SDK choice
 *
 * Flutter uses `firebase_messaging`; this port uses `expo-notifications`
 * for the permission prompt instead of `@react-native-firebase/messaging`:
 * it is Expo's own recommended module (see `react_native_app/AGENTS.md`),
 * and its `requestPermissionsAsync()` shows Android 13+'s
 * `POST_NOTIFICATIONS` system dialog directly, whereas RNFB messaging's
 * Android `requestPermission()` does not and needs a separate
 * `PermissionsAndroid` call. When token registration lands, either
 * `expo-notifications`' `getDevicePushTokenAsync()` (the raw FCM token on
 * Android, same Firebase project via `google-services.json`) or RNFB
 * messaging can be added behind this same interface.
 */
import { Platform } from 'react-native';

/** Ports the Dart `PushNotificationGateway` interface. */
export interface PushNotificationGateway {
  /** Sets up the underlying push SDK. Safe to call more than once. Must run before {@link requestPermission}/{@link hasPermission}. */
  initialize(): Promise<void>;
  /**
   * Prompts for permission if it hasn't already been decided; resolves
   * whether push is now allowed. On Android 13+ this is what shows the
   * system dialog; on older Android permission is granted at install time
   * and this resolves `true` without prompting.
   */
  requestPermission(): Promise<boolean>;
  /** Reads the current permission status without prompting. */
  hasPermission(): Promise<boolean>;
}

/** Reports push as unavailable everywhere. Kept as a test/fallback double. */
export class UnsupportedPushNotificationGateway implements PushNotificationGateway {
  async initialize(): Promise<void> {}

  async requestPermission(): Promise<boolean> {
    return false;
  }

  async hasPermission(): Promise<boolean> {
    return false;
  }
}

/** The subset of a permission response from `expo-notifications` this gateway reads. */
export interface NotificationPermissionResponse {
  granted: boolean;
  ios?: { status: number } | null;
}

/** The subset of `expo-notifications` this gateway depends on, so tests can inject a fake. */
export interface NotificationPermissionsApi {
  requestPermissionsAsync(): Promise<NotificationPermissionResponse>;
  getPermissionsAsync(): Promise<NotificationPermissionResponse>;
}

/** `expo-notifications`' `IosAuthorizationStatus.PROVISIONAL`. */
const IOS_AUTHORIZATION_STATUS_PROVISIONAL = 3;

export interface ExpoNotificationsGatewayOptions {
  /** Defaults to `Platform.OS`. */
  platformOS?: string;
  /** Defaults to the real `expo-notifications` module, loaded lazily. */
  loadApi?: () => Promise<NotificationPermissionsApi>;
}

const loadExpoNotifications = async (): Promise<NotificationPermissionsApi> => import('expo-notifications');

/**
 * Real {@link PushNotificationGateway}, the RN equivalent of Flutter's
 * `FirebaseMessagingGateway`.
 *
 * **Android only**, like Flutter's (`_supportsPush`): the owner has no Apple
 * Developer account yet (#55), so every method no-ops (resolving `false`)
 * on iOS and web without touching the native module.
 */
export class ExpoNotificationsGateway implements PushNotificationGateway {
  private readonly platformOS: string;
  private readonly loadApi: () => Promise<NotificationPermissionsApi>;

  constructor({ platformOS = Platform.OS, loadApi = loadExpoNotifications }: ExpoNotificationsGatewayOptions = {}) {
    this.platformOS = platformOS;
    this.loadApi = loadApi;
  }

  private get supportsPush(): boolean {
    return this.platformOS === 'android';
  }

  async initialize(): Promise<void> {
    if (!this.supportsPush) return;
    // Flutter's initialize() is `Firebase.initializeApp()`. Here the native
    // module needs no explicit setup, so this only loads it -- surfacing a
    // missing native module early, inside the best-effort startup step.
    await this.loadApi();
  }

  async requestPermission(): Promise<boolean> {
    if (!this.supportsPush) return false;
    const api = await this.loadApi();
    return isGranted(await api.requestPermissionsAsync());
  }

  async hasPermission(): Promise<boolean> {
    if (!this.supportsPush) return false;
    const api = await this.loadApi();
    return isGranted(await api.getPermissionsAsync());
  }
}

/** Mirrors Flutter's `_isGranted`: authorized or (iOS) provisional. */
function isGranted(response: NotificationPermissionResponse): boolean {
  return response.granted || response.ios?.status === IOS_AUTHORIZATION_STATUS_PROVISIONAL;
}

/** Ports Dart's `PushNotifications`: a process-wide, test-swappable gateway. */
export const PushNotifications: { instance: PushNotificationGateway } = {
  instance: new ExpoNotificationsGateway(),
};
