/**
 * Ports the "customer role sign-in is unchanged" case from
 * `flutter_app/test/login_screen_test.dart`'s "merchant redirect after
 * sign-in" group (issue #365).
 *
 * This is a separate file from `login.test.tsx` (which has the suite's
 * other cases, including the sibling `merchant`-role redirect case) purely
 * to work around an environment limitation, not a design choice: this
 * repo's `react_native_app/package-lock.json` already pins a `react`
 * (`19.2.3`) that does not satisfy `test-renderer`'s bundled
 * `react-reconciler@0.34.0`'s own peer requirement (`react@^19.3.0`) --
 * `npm install` prints this exact conflict, pre-existing before this
 * issue's own changes. Under that mismatch, a *second* real end-to-end
 * "render a fresh `LoginScreen`, press Sign in, await its fire-and-forget
 * submit chain settling" cycle *in the same Jest file* reliably corrupts
 * React's `act()`/commit bookkeeping badly enough that every subsequent
 * render in that file comes back empty (`toJSON() === null`) or drops a
 * `setState` call silently -- reproduced with a minimal repro isolated
 * down to exactly that pattern, independent of this screen's or this
 * suite's own code. One such cycle per file is reliably fine, so each of
 * this issue's "merchant redirect after sign-in" cases that needs one gets
 * its own file instead (see also `login-invalid-credentials.test.tsx`,
 * `login-navigation-error.test.tsx`). Fixing the underlying version
 * mismatch is a repo-wide dependency change outside this issue's scope.
 *
 * See `login.test.tsx`'s top comment for what's mocked and why.
 */
import { act, fireEvent, type RenderResult } from '@testing-library/react-native';
import { router } from 'expo-router';

import { renderWithProviders } from '@/test-utils';
import { createFakeSupabaseClient, fakeSupabaseOk, type FakeSupabaseClient } from '@/test-utils/fake-supabase-client';
import { ErrorReporting, NoopErrorReporter, type ErrorReporter } from '@/platform/error-reporting/error-reporter';
import { AppRoutes } from '@/platform/navigation/app-routes';
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

/** Presses `element` and settles the screen's fire-and-forget submit chain before returning -- see `login.test.tsx`'s own `pressAndSettle` doc comment for why this needs a trailing real timer tick plus a second `act()` call. */
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

describe('LoginScreen -- merchant redirect after sign-in (customer role)', () => {
  let previousReporter: ErrorReporter;

  beforeEach(() => {
    mockFakeClient = createFakeSupabaseClient();
    mockSignInWithPassword = jest.fn();
    (router.canGoBack as jest.Mock).mockReturnValue(false);
    useSessionStore.setState({ status: 'signedOut', session: null, userId: null });
    merchantSessionGate.reset();
    previousReporter = ErrorReporting.instance;
    ErrorReporting.instance = new NoopErrorReporter();
  });

  afterEach(() => {
    ErrorReporting.instance = previousReporter;
  });

  test("a customer-role account's sign-in is unchanged: it lands on the customer home", async () => {
    queueSuccessfulSignIn('customer-1', 'user@example.com');
    mockFakeClient.queueTableResponse('profiles', fakeSupabaseOk({ role: 'customer' }));

    const result = await renderLogin();
    enterCredentials(result, 'user@example.com', 'password123');
    await pressAndSettle(result.getByText('Sign in'));

    expect(router.replace).toHaveBeenCalledWith(AppRoutes.mainApp);
    expect(merchantSessionGate.store.getState().isMerchantRole).toBe(false);
    expect(result.queryByText(/Login failed/)).toBeNull();
  });
});
