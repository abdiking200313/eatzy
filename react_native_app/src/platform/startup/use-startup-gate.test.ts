/**
 * Ports `startup_gate_test.dart`'s loading/ready cases against
 * {@link useStartupGate} (issue #360) -- see that hook's top comment for
 * why the Flutter test's failed/retry case has no port here.
 *
 * `@/stores/session-store` and `@/stores/onboarding-store` are both
 * mocked: this is about `useStartupGate`'s own combination logic, not
 * either store's real behavior (covered by `session-store.test.ts` and
 * `onboarding-store.test.ts`). The push-permission startup step (issue
 * #405) is mocked too; its own behavior is covered by
 * `request-startup-push-permission.test.ts`.
 */
import { act, renderHook, waitFor } from '@testing-library/react-native';

import { useStartupGate } from './use-startup-gate';

let mockSessionState: { status: string; userId: string | null };
let mockOnboardingState: { status: string; hasSeenOnboarding: boolean };
const mockLoad = jest.fn();
const mockRequestStartupPushPermission = jest.fn<Promise<void>, [{ userId: string | null }]>();

jest.mock('@/platform/notifications/request-startup-push-permission', () => ({
  requestStartupPushPermission: (options: { userId: string | null }) => mockRequestStartupPushPermission(options),
}));

jest.mock('@/stores/session-store', () => ({
  useSessionStore: (selector: (state: typeof mockSessionState) => unknown) =>
    selector(mockSessionState),
}));

jest.mock('@/stores/onboarding-store', () => ({
  useOnboardingStore: (
    selector: (state: typeof mockOnboardingState & { load: typeof mockLoad }) => unknown,
  ) => selector({ ...mockOnboardingState, load: mockLoad }),
}));

describe('useStartupGate', () => {
  beforeEach(() => {
    mockLoad.mockClear();
    mockRequestStartupPushPermission.mockReset();
    mockRequestStartupPushPermission.mockResolvedValue(undefined);
  });

  it('starts load() once, on mount', async () => {
    mockSessionState = { status: 'loading', userId: null };
    mockOnboardingState = { status: 'idle', hasSeenOnboarding: false };

    await renderHook(() => useStartupGate());

    expect(mockLoad).toHaveBeenCalledTimes(1);
  });

  it('reports loading while the session status is still loading', async () => {
    mockSessionState = { status: 'loading', userId: null };
    mockOnboardingState = { status: 'ready', hasSeenOnboarding: false };

    const { result } = await renderHook(() => useStartupGate());

    expect(result.current.status).toBe('loading');
  });

  it('reports loading while the onboarding flag has not resolved yet', async () => {
    mockSessionState = { status: 'signedOut', userId: null };
    mockOnboardingState = { status: 'loading', hasSeenOnboarding: false };

    const { result } = await renderHook(() => useStartupGate());

    expect(result.current.status).toBe('loading');
  });

  it('reports ready with the resolved values once both are known (signed out, has seen onboarding)', async () => {
    mockSessionState = { status: 'signedOut', userId: null };
    mockOnboardingState = { status: 'ready', hasSeenOnboarding: true };

    const { result } = await renderHook(() => useStartupGate());

    await waitFor(() =>
      expect(result.current).toEqual({
        status: 'ready',
        isLoggedIn: false,
        hasSeenOnboarding: true,
      }),
    );
  });

  it('reports ready and signed in once both are known', async () => {
    mockSessionState = { status: 'signedIn', userId: 'user-1' };
    mockOnboardingState = { status: 'ready', hasSeenOnboarding: false };

    const { result } = await renderHook(() => useStartupGate());

    await waitFor(() =>
      expect(result.current).toEqual({
        status: 'ready',
        isLoggedIn: true,
        hasSeenOnboarding: false,
      }),
    );
  });

  it('does not ask for push permission while the session is still restoring', async () => {
    mockSessionState = { status: 'loading', userId: null };
    mockOnboardingState = { status: 'ready', hasSeenOnboarding: false };

    await renderHook(() => useStartupGate());

    expect(mockRequestStartupPushPermission).not.toHaveBeenCalled();
  });

  it('asks for push permission once the restored session is known, with its user id', async () => {
    mockSessionState = { status: 'signedIn', userId: 'user-1' };
    mockOnboardingState = { status: 'ready', hasSeenOnboarding: true };

    await renderHook(() => useStartupGate());

    await waitFor(() => expect(mockRequestStartupPushPermission).toHaveBeenCalledWith({ userId: 'user-1' }));
  });

  it('keeps reporting loading until the push permission step settles', async () => {
    let settle: () => void = () => {};
    mockRequestStartupPushPermission.mockReturnValue(
      new Promise<void>((resolve) => {
        settle = resolve;
      }),
    );
    mockSessionState = { status: 'signedOut', userId: null };
    mockOnboardingState = { status: 'ready', hasSeenOnboarding: true };

    const { result } = await renderHook(() => useStartupGate());

    expect(result.current.status).toBe('loading');
    await act(async () => settle());
    await waitFor(() => expect(result.current.status).toBe('ready'));
  });

  it('asks only once per launch, not again on a later sign-in', async () => {
    mockSessionState = { status: 'signedOut', userId: null };
    mockOnboardingState = { status: 'ready', hasSeenOnboarding: true };

    const { rerender } = await renderHook(() => useStartupGate());
    await waitFor(() => expect(mockRequestStartupPushPermission).toHaveBeenCalledTimes(1));

    mockSessionState = { status: 'signedIn', userId: 'user-1' };
    await rerender({});

    expect(mockRequestStartupPushPermission).toHaveBeenCalledTimes(1);
    expect(mockRequestStartupPushPermission).toHaveBeenCalledWith({ userId: null });
  });
});
