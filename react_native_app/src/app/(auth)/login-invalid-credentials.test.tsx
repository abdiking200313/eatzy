/**
 * Ports the "invalid credentials" case from
 * `flutter_app/test/login_screen_test.dart`'s "merchant redirect after
 * sign-in" group (issue #365): a failed sign-in shows `'Login failed: '`
 * plus `describeAuthError`'s exact mapped message, never a raw error.
 *
 * Kept in its own file for the same pre-existing environment reason
 * `login-customer-redirect.test.tsx`'s top comment explains in full --
 * see that file.
 *
 * See `login.test.tsx`'s top comment for what's mocked and why.
 */
import { act, fireEvent, type RenderResult } from '@testing-library/react-native';
import { AuthApiError } from '@supabase/supabase-js';
import { router } from 'expo-router';

import { renderWithProviders } from '@/test-utils';
import { createFakeSupabaseClient, type FakeSupabaseClient } from '@/test-utils/fake-supabase-client';
import { ErrorReporting, NoopErrorReporter, type ErrorReporter } from '@/platform/error-reporting/error-reporter';
import { merchantSessionGate } from '@/stores/merchant-session-gate';
import { useSessionStore } from '@/stores/session-store';

import LoginScreen from './login';

let mockFakeClient: FakeSupabaseClient;
let mockSignInWithPassword: jest.Mock;

jest.mock('expo-router', () => ({
  router: {
    canGoBack: jest.fn(() => false),
    back: jest.fn(),
    replace: jest.fn(),
    push: jest.fn(),
  },
}));

jest.mock('@/platform/supabase/client', () => ({
  supabase: {
    auth: {
      onAuthStateChange: () => ({ data: { subscription: { unsubscribe: () => {} } } }),
      signInWithPassword: (credentials: { email: string; password: string }) => mockSignInWithPassword(credentials),
    },
    from: (table: string) => mockFakeClient.from(table),
  },
}));

/** Queues a failed sign-in with a *real* `AuthApiError` (`isAuthError` checks for an internal `__isAuthError` marker set by the real class -- a plain `{code, message}` object literal would silently fall through to the generic fallback message instead). */
function queueFailedSignIn(code: string, status = 400) {
  mockSignInWithPassword.mockImplementation(async () => ({
    data: { user: null, session: null },
    error: new AuthApiError('mock message', status, code),
  }));
}

async function renderLogin() {
  return renderWithProviders(<LoginScreen />);
}

function enterCredentials({ getByPlaceholderText }: RenderResult, email: string, password: string) {
  fireEvent.changeText(getByPlaceholderText('you@example.com'), email);
  fireEvent.changeText(getByPlaceholderText('Enter your password'), password);
}

async function pressAndSettle(element: unknown) {
  await act(async () => {
    fireEvent.press(element as never);
    for (let i = 0; i < 20; i++) {
      await Promise.resolve();
    }
    await new Promise((resolve) => setTimeout(resolve, 0));
    await new Promise((resolve) => setTimeout(resolve, 0));
  });
  // A second, separate act() call forces React to flush/commit anything
  // scheduled during the async one above but not yet committed.
  await act(async () => {});
}

describe('LoginScreen -- merchant redirect after sign-in (invalid credentials)', () => {
  let previousReporter: ErrorReporter;

  beforeEach(() => {
    mockFakeClient = createFakeSupabaseClient();
    mockSignInWithPassword = jest.fn();
    (router.canGoBack as jest.Mock).mockReturnValue(false);
    useSessionStore.setState({ status: 'signedOut', session: null, userId: null });
    merchantSessionGate.reset();
    // Keeps describeAuthError's deliberate `ErrorReporting.instance.
    // reportError` side effect from spamming the test output for this
    // expected-failure case -- mirrors `auth-error-message.test.ts`'s own
    // posture.
    previousReporter = ErrorReporting.instance;
    ErrorReporting.instance = new NoopErrorReporter();
  });

  afterEach(() => {
    ErrorReporting.instance = previousReporter;
  });

  test('shows "Login failed: Incorrect email or password." for invalid credentials', async () => {
    queueFailedSignIn('invalid_credentials');

    const result = await renderLogin();
    enterCredentials(result, 'user@example.com', 'wrong-password');
    await pressAndSettle(result.getByText('Sign in'));

    expect(result.getByText('Login failed: Incorrect email or password.')).toBeOnTheScreen();
    expect(router.replace).not.toHaveBeenCalled();
    expect(merchantSessionGate.store.getState().resolvedUserId).toBeNull();
  });
});
