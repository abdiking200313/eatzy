/**
 * Covers {@link ExpoNotificationsGateway} (issue #405), the RN equivalent of
 * Flutter's `FirebaseMessagingGateway`: Android-only, and "granted" means
 * authorized or (iOS) provisional, mirroring its `_isGranted`.
 */
import {
  ExpoNotificationsGateway,
  type NotificationPermissionResponse,
  type NotificationPermissionsApi,
} from './push-notifications';

function fakeApi(response: NotificationPermissionResponse) {
  const api = {
    requestPermissionsAsync: jest.fn<Promise<NotificationPermissionResponse>, []>(async () => response),
    getPermissionsAsync: jest.fn<Promise<NotificationPermissionResponse>, []>(async () => response),
  } satisfies NotificationPermissionsApi;
  const loadApi = jest.fn(async () => api);
  return { api, loadApi };
}

describe('ExpoNotificationsGateway', () => {
  it('requests permission on Android and reports it granted', async () => {
    const { api, loadApi } = fakeApi({ granted: true });
    const gateway = new ExpoNotificationsGateway({ platformOS: 'android', loadApi });

    await gateway.initialize();

    await expect(gateway.requestPermission()).resolves.toBe(true);
    expect(api.requestPermissionsAsync).toHaveBeenCalledTimes(1);
  });

  it('reports a denied permission as not granted', async () => {
    const { loadApi } = fakeApi({ granted: false });
    const gateway = new ExpoNotificationsGateway({ platformOS: 'android', loadApi });

    await expect(gateway.requestPermission()).resolves.toBe(false);
  });

  it('treats an iOS provisional authorization as granted', async () => {
    const { loadApi } = fakeApi({ granted: false, ios: { status: 3 } });
    const gateway = new ExpoNotificationsGateway({ platformOS: 'android', loadApi });

    await expect(gateway.requestPermission()).resolves.toBe(true);
  });

  it('reads the current status without prompting in hasPermission()', async () => {
    const { api, loadApi } = fakeApi({ granted: true });
    const gateway = new ExpoNotificationsGateway({ platformOS: 'android', loadApi });

    await expect(gateway.hasPermission()).resolves.toBe(true);
    expect(api.getPermissionsAsync).toHaveBeenCalledTimes(1);
    expect(api.requestPermissionsAsync).not.toHaveBeenCalled();
  });

  it.each(['ios', 'web'])('no-ops on %s without touching the native module', async (platformOS) => {
    const { loadApi } = fakeApi({ granted: true });
    const gateway = new ExpoNotificationsGateway({ platformOS, loadApi });

    await gateway.initialize();
    await expect(gateway.requestPermission()).resolves.toBe(false);
    await expect(gateway.hasPermission()).resolves.toBe(false);
    expect(loadApi).not.toHaveBeenCalled();
  });
});
