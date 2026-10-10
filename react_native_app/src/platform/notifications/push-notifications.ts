/**
 * Ports the `PushNotificationGateway` seam and `PushNotifications` access
 * point from `flutter_app/lib/platform/notifications/push_notifications.dart`
 * (issue #401 / P8-05 needs the seam for the Settings "Push Notifications"
 * toggle).
 *
 * The real Firebase Cloud Messaging-backed gateway (and the
 * `@react-native-firebase/messaging` dependency) lands with #405 / P8-10,
 * which swaps it in as {@link PushNotifications.instance}. Until then the
 * default {@link UnsupportedPushNotificationGateway} reports push as
 * unavailable -- the same answer Flutter's `FirebaseMessagingGateway` gives
 * on any platform where push isn't wired (`_supportsPush == false`) -- so
 * the toggle never claims push is on when nothing can deliver it.
 */

/** Ports the Dart `PushNotificationGateway` interface. */
export interface PushNotificationGateway {
  /** Sets up the underlying push SDK. Safe to call more than once. */
  initialize(): Promise<void>;
  /** Prompts for permission if undecided; resolves whether push is now allowed. */
  requestPermission(): Promise<boolean>;
  /** Reads the current permission status without prompting. */
  hasPermission(): Promise<boolean>;
}

/** Push is not wired yet in this app (see this file's top comment). */
export class UnsupportedPushNotificationGateway implements PushNotificationGateway {
  async initialize(): Promise<void> {}

  async requestPermission(): Promise<boolean> {
    return false;
  }

  async hasPermission(): Promise<boolean> {
    return false;
  }
}

/** Ports Dart's `PushNotifications`: a process-wide, test-swappable gateway. */
export const PushNotifications: { instance: PushNotificationGateway } = {
  instance: new UnsupportedPushNotificationGateway(),
};
