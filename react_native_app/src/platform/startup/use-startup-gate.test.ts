/**
 * Ports `startup_gate_test.dart`'s loading/ready cases against
 * {@link useStartupGate} (issue #360) -- see that hook's top comment for
 * why the Flutter test's failed/retry case has no port here.
 *
 * `@/stores/session-store` and `@/stores/onboarding-store` are both
 * mocked: this is about `useStartupGate`'s own combination logic, not
 * either store's real behavior (covered by `session-store.test.ts` and
 * `onboarding-store.test.ts`).
 */
import { renderHook, waitFor } from '@testing-library/react-native';

import { useStartupGate } from './use-startup-gate';

let mockSessionState: { status: string; userId: string | null };
let mockOnboardingState: { status: string; hasSeenOnboarding: boolean };
const mockLoad = jest.fn();

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
});
