/**
 * Ports the push-notification step of
 * `flutter_app/lib/platform/startup/startup_gate.dart`'s
 * `runStartupSequence` (issue #405 / P8-10):
 *
 * ```dart
 * await _runBestEffort('PushNotifications.initialize', () async { ... });
 * ```
 *
 * Initializes the push SDK, then asks for notification permission -- but
 * only when the stored preference allows it: a returning signed-in user who
 * turned "Push Notifications" off in Settings is not re-prompted, while a
 * signed-out user (or one with no saved preference) falls back to
 * {@link DEFAULT_NOTIFICATION_PREFERENCES}, which has push on.
 *
 * Best-effort like every non-fatal Flutter startup step: each call is
 * individually timed out, and any failure is reported via
 * {@link ErrorReporting} and swallowed, so a missing native module or a
 * slow permission dialog never blocks reaching the app.
 */
import {
  AsyncStorageNotificationPreferencesStorage,
  DEFAULT_NOTIFICATION_PREFERENCES,
  type NotificationPreferencesStorage,
} from '@/features/settings/api/notification-preferences-repository';
import { ErrorReporting } from '@/platform/error-reporting/error-reporter';

import { PushNotifications, type PushNotificationGateway } from './push-notifications';

/** Mirrors Flutter's `kStartupNetworkTimeout`. */
export const STARTUP_STEP_TIMEOUT_MS = 15_000;

/** Mirrors the `_runBestEffort` context label Flutter reports failures under. */
export const PUSH_STARTUP_ERROR_CONTEXT = 'PushNotifications.initialize';

export interface RequestStartupPushPermissionOptions {
  /** The restored session's user id, or `null` when signed out. */
  userId: string | null;
  /** Defaults to {@link PushNotifications.instance}. */
  gateway?: PushNotificationGateway;
  /** Defaults to the real AsyncStorage-backed storage. */
  preferencesStorage?: NotificationPreferencesStorage;
  /** Defaults to {@link STARTUP_STEP_TIMEOUT_MS}. */
  timeoutMs?: number;
}

function withTimeout<T>(promise: Promise<T>, ms: number, label: string): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new Error(`${label} timed out after ${ms}ms`)), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

/** Never rejects. Resolves once the step finishes, fails, or times out. */
export async function requestStartupPushPermission({
  userId,
  gateway = PushNotifications.instance,
  preferencesStorage,
  timeoutMs = STARTUP_STEP_TIMEOUT_MS,
}: RequestStartupPushPermissionOptions): Promise<void> {
  try {
    await withTimeout(gateway.initialize(), timeoutMs, 'PushNotifications.initialize');
    const preferences =
      userId == null
        ? DEFAULT_NOTIFICATION_PREFERENCES
        : await withTimeout(
            (preferencesStorage ?? new AsyncStorageNotificationPreferencesStorage()).read(userId),
            timeoutMs,
            'NotificationPreferencesStorage.read',
          );
    if (preferences.pushNotifications) {
      await withTimeout(gateway.requestPermission(), timeoutMs, 'PushNotifications.requestPermission');
    }
  } catch (error) {
    ErrorReporting.instance.reportError(
      error,
      error instanceof Error ? error.stack : undefined,
      PUSH_STARTUP_ERROR_CONTEXT,
    );
  }
}
