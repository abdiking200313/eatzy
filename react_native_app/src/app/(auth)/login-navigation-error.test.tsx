/**
 * Ports the "does not show a failed message when navigation throws after a
 * successful sign-in" case from `flutter_app/test/login_screen_test.dart`'s
 * "merchant redirect after sign-in" group (issue #365): the post-sign-in
 * `router.replace` call sits outside the try/catch around `authService.
 * signInWithEmailPassword`, so a navigation failure after a *successful*
 * sign-in must never surface as a sign-in failure -- see `login.tsx`'s own
 * doc comment and the Dart file's issue #295 comment.
 *
 * `login.tsx`'s submit handler is fire-and-forget (mirroring the Dart
 * screen's own un-awaited `onPressed: _login`), but unlike the Dart
 * original it attaches a `.catch` that reports (not silently swallows) a
 * post-success failure via `ErrorReporting` -- a deliberate, small
 * departure from a literal 1:1 port. A true dangling, uncaught rejection
 * (what the Dart test's `runZonedGuarded` reproduces) is not testable here:
 * `jest-circus` (this project's Jest test runner) installs its own
 * exclusive `process.on('unhandledRejection', ...)` handler for the
 * duration of each test run (see `node_modules/jest-circus/build/
 * globalErrorHandlers.js`'s `injectGlobalErrorHandlers`, which *removes*
 * every other registered listener first) and unconditionally fails the
 * currently-running test when one fires, regardless of any listener a test
 * itself adds. Catching and reporting the error instead avoids a genuine
 * unhandled rejection in production too (a real benefit, not just a test
 * workaround) and keeps the one invariant this case actually cares about
 * -- a failure after a successful sign-in is never shown as "Login
 * failed" -- both true and testable.
 *
 * Kept in its own file for the same pre-existing environment reason
 * `login-customer-redirect.test.tsx`'s top comment explains in full --
 * see that file.
 *
 * See `login.test.tsx`'s top comment for what's mocked and why.
 */
import { act, fireEvent, type RenderResult } from '@testing-library/react-native';
import { router } from 'expo-router';

import { renderWithProviders } from '@/test-utils';
import { createFakeSupabaseClient, fakeSupabaseOk, type FakeSupabaseClient } from '@/test-utils/fake-supabase-client';
import { ErrorReporting, type ErrorReporter } from '@/platform/error-reporting/error-reporter';
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

function queueSuccessfulSignIn(userId: string, email: string) {
  const user = {
    id: userId,
    aud: 'authenticated',
    email,
    app_metadata: {},
    user_metadata: {},
    created_at: new Date().toISOString(),
  };
  const session = {
    access_token: 'mock-access-token',
    refresh_token: 'mock-refresh-token',
    expires_in: 3600,
    token_type: 'bearer',
    user,
  };
  mockSignInWithPassword.mockImplementation(async () => ({ data: { user, session }, error: null }));
}

async function renderLogin() {
  return renderWithProviders(<LoginScreen />);
}

function enterCredentials({ getByPlaceholderText }: RenderResult, email: string, password: string) {
  fireEvent.changeText(getByPlaceholderText('you@example.com'), email);
  fireEvent.changeText(getByPlaceholderText('Enter your password'), password);
}

/** Presses `element` and settles the screen's submit chain before returning -- see `login.test.tsx`'s own `pressAndSettle` doc comment for why this needs a trailing real timer tick plus a second `act()` call. */
async function pressAndSettle(element: unknown) {
  await act(async () => {
    fireEvent.press(element as never);
    for (let i = 0; i < 20; i++) {
      await Promise.resolve();
    }
    await new Promise((resolve) => setTimeout(resolve, 0));
    await new Promise((resolve) => setTimeout(resolve, 0));
  });
  await act(async () => {});
}

describe('LoginScreen -- merchant redirect after sign-in (navigation throws after success)', () => {
  let previousReporter: ErrorReporter;
  let reportError: jest.Mock;

  beforeEach(() => {
    mockFakeClient = createFakeSupabaseClient();
    mockSignInWithPassword = jest.fn();
    (router.canGoBack as jest.Mock).mockReturnValue(false);
    useSessionStore.setState({ status: 'signedOut', session: null, userId: null });
    merchantSessionGate.reset();
    previousReporter = ErrorReporting.instance;
    reportError = jest.fn();
    ErrorReporting.instance = { reportError };
  });

  afterEach(() => {
    ErrorReporting.instance = previousReporter;
  });

  test('does not show a failed message when navigation throws after a successful sign-in', async () => {
    queueSuccessfulSignIn('customer-2', 'user@example.com');
    mockFakeClient.queueTableResponse('profiles', fakeSupabaseOk({ role: 'customer' }));
    const navigationError = new Error('navigation failed');
    (router.replace as jest.Mock).mockImplementation(() => {
      throw navigationError;
    });

    const result = await renderLogin();
    enterCredentials(result, 'user@example.com', 'password123');
    await pressAndSettle(result.getByText('Sign in'));

    expect(router.replace).toHaveBeenCalled();
    // The failure is reported for diagnostics (this app's established
    // `ErrorReporting` convention -- see `login.tsx`'s own doc comment)
    // rather than swallowed outright or surfaced as a sign-in failure.
    expect(reportError).toHaveBeenCalledWith(navigationError, navigationError.stack, 'LoginScreen.handlePress');
    expect(result.queryByText(/Login failed/)).toBeNull();
  });
});
