/**
 * Ports the push-notification step of `startup_gate.dart`'s
 * `runStartupSequence` (issue #405): prompt only when the stored preference
 * allows it, and never let a failure escape.
 */
import { ErrorReporting, type ErrorReporter } from '@/platform/error-reporting/error-reporter';
import { DEFAULT_NOTIFICATION_PREFERENCES } from '@/features/settings/api/notification-preferences-repository';
import { FakePushNotificationGateway, MemoryNotificationPreferencesStorage } from '@/test-utils';

import { PUSH_STARTUP_ERROR_CONTEXT, requestStartupPushPermission } from './request-startup-push-permission';

describe('requestStartupPushPermission', () => {
  const originalReporter = ErrorReporting.instance;
  let reportError: jest.Mock;

  beforeEach(() => {
    reportError = jest.fn();
    ErrorReporting.instance = { reportError } satisfies ErrorReporter;
  });

  afterEach(() => {
    ErrorReporting.instance = originalReporter;
  });

  it('prompts a signed-out user, falling back to the defaults (push on)', async () => {
    const gateway = new FakePushNotificationGateway();
    const initialize = jest.spyOn(gateway, 'initialize');

    await requestStartupPushPermission({ userId: null, gateway });

    expect(initialize).toHaveBeenCalledTimes(1);
    expect(gateway.requestPermissionCallCount).toBe(1);
    expect(reportError).not.toHaveBeenCalled();
  });

  it('prompts a signed-in user with no saved preference', async () => {
    const gateway = new FakePushNotificationGateway();

    await requestStartupPushPermission({
      userId: 'user-1',
      gateway,
      preferencesStorage: new MemoryNotificationPreferencesStorage(),
    });

    expect(gateway.requestPermissionCallCount).toBe(1);
  });

  it('does not re-prompt a signed-in user who turned push notifications off', async () => {
    const gateway = new FakePushNotificationGateway();
    const preferencesStorage = new MemoryNotificationPreferencesStorage();
    await preferencesStorage.write('user-1', { ...DEFAULT_NOTIFICATION_PREFERENCES, pushNotifications: false });

    await requestStartupPushPermission({ userId: 'user-1', gateway, preferencesStorage });

    expect(gateway.requestPermissionCallCount).toBe(0);
  });

  it('reads the preference of the restored user, not another account', async () => {
    const gateway = new FakePushNotificationGateway();
    const preferencesStorage = new MemoryNotificationPreferencesStorage();
    await preferencesStorage.write('user-2', { ...DEFAULT_NOTIFICATION_PREFERENCES, pushNotifications: false });

    await requestStartupPushPermission({ userId: 'user-1', gateway, preferencesStorage });

    expect(gateway.requestPermissionCallCount).toBe(1);
  });

  it('reports and swallows an initialize failure without prompting', async () => {
    const gateway = new FakePushNotificationGateway();
    const failure = new Error('native module missing');
    jest.spyOn(gateway, 'initialize').mockRejectedValue(failure);

    await expect(requestStartupPushPermission({ userId: null, gateway })).resolves.toBeUndefined();

    expect(gateway.requestPermissionCallCount).toBe(0);
    expect(reportError).toHaveBeenCalledWith(failure, failure.stack, PUSH_STARTUP_ERROR_CONTEXT);
  });

  it('gives up on a permission request that never settles once the timeout elapses', async () => {
    jest.useFakeTimers();
    try {
      const gateway = new FakePushNotificationGateway();
      jest.spyOn(gateway, 'requestPermission').mockReturnValue(new Promise<boolean>(() => {}));

      const done = requestStartupPushPermission({ userId: null, gateway, timeoutMs: 1_000 });
      await jest.advanceTimersByTimeAsync(1_000);
      await expect(done).resolves.toBeUndefined();

      expect(reportError).toHaveBeenCalledWith(expect.any(Error), expect.any(String), PUSH_STARTUP_ERROR_CONTEXT);
    } finally {
      jest.useRealTimers();
    }
  });
});
