/**
 * Exercises {@link usePasswordRecoveryRedirect}'s wiring (issue #361):
 * given the URL the app was opened/resumed with, it starts the recovery
 * session and redirects, or does nothing for an unrelated URL.
 * `expo-linking`'s `useURL`, `expo-router`'s `useRouter`, and `@/platform/
 * supabase/client` are all mocked -- this is about the hook's own
 * orchestration, not those modules' real behavior (covered elsewhere:
 * `password-recovery.test.ts` for the parsing/session logic this hook
 * delegates to).
 */
import { renderHook, waitFor } from '@testing-library/react-native';

import { PASSWORD_RECOVERY_REDIRECT_URL } from './password-recovery';
import { usePasswordRecoveryRedirect } from './use-password-recovery-redirect';

// Module-scoped variables a `jest.mock()` factory closes over must be
// prefixed `mock` (case-insensitive) -- babel-plugin-jest-hoist only
// whitelists that naming pattern for out-of-scope variable access, since
// otherwise it can't guarantee the variable is initialized before the
// hoisted mock runs.
const mockSetSession = jest.fn().mockResolvedValue(undefined);
const mockReplace = jest.fn();
let mockCurrentUrl: string | null = null;

jest.mock('expo-linking', () => ({
  useURL: () => mockCurrentUrl,
}));

jest.mock('expo-router', () => ({
  useRouter: () => ({ replace: mockReplace }),
}));

jest.mock('@/platform/supabase/client', () => ({
  supabase: { auth: { setSession: (...args: unknown[]) => mockSetSession(...args) } },
}));

describe('usePasswordRecoveryRedirect', () => {
  beforeEach(() => {
    mockCurrentUrl = null;
    mockSetSession.mockClear();
    mockReplace.mockClear();
  });

  it('does nothing when there is no URL yet', async () => {
    await renderHook(() => usePasswordRecoveryRedirect());

    expect(mockSetSession).not.toHaveBeenCalled();
    expect(mockReplace).not.toHaveBeenCalled();
  });

  it('does nothing for a URL that is not a password-recovery link', async () => {
    mockCurrentUrl = 'zivo://track-order/food/order-1';

    await renderHook(() => usePasswordRecoveryRedirect());

    expect(mockSetSession).not.toHaveBeenCalled();
    expect(mockReplace).not.toHaveBeenCalled();
  });

  it('starts the session and redirects to /reset-password for a recovery link', async () => {
    mockCurrentUrl = `${PASSWORD_RECOVERY_REDIRECT_URL}#access_token=abc&refresh_token=def&type=recovery`;

    await renderHook(() => usePasswordRecoveryRedirect());

    await waitFor(() => {
      expect(mockSetSession).toHaveBeenCalledWith({ access_token: 'abc', refresh_token: 'def' });
      expect(mockReplace).toHaveBeenCalledWith('/reset-password');
    });
  });

  it('only handles the same URL once even if the hook re-runs', async () => {
    mockCurrentUrl = `${PASSWORD_RECOVERY_REDIRECT_URL}#access_token=abc&refresh_token=def&type=recovery`;

    const { rerender } = await renderHook(() => usePasswordRecoveryRedirect());

    await waitFor(() => expect(mockReplace).toHaveBeenCalledTimes(1));

    rerender(undefined);

    expect(mockSetSession).toHaveBeenCalledTimes(1);
    expect(mockReplace).toHaveBeenCalledTimes(1);
  });
});
