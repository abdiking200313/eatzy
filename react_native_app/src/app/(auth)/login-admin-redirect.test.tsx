/**
 * Ports the "an admin-role account also lands on the merchant dashboard"
 * case from `flutter_app/test/login_screen_test.dart`'s "merchant redirect
 * after sign-in" group (issue #365/#369). `isAuthorizedMerchantRole`'s own
 * `merchant`-vs-`admin`-vs-`customer` mapping is already exhaustively
 * unit-tested in `merchant-role-service.test.ts` -- this is the end-to-end
 * check (mirroring `login.test.tsx`'s sibling `merchant`-role case) that
 * `login.tsx` itself routes an `admin` role the same way as `merchant`,
 * not just `isAuthorizedMerchantRole` in isolation.
 *
 * This is a separate file from `login.test.tsx`/`login-customer-
 * redirect.test.tsx` purely to work around an environment limitation, not a
 * design choice -- see `login-customer-redirect.test.tsx`'s top comment for
 * the full explanation of why each "merchant redirect after sign-in" case
 * that needs a real end-to-end submit cycle gets its own file.
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

/** See `login.test.tsx`'s own `pressAndSettle` doc comment for why this needs a trailing real timer tick plus a second `act()` call. */
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

describe('LoginScreen -- merchant redirect after sign-in (admin role)', () => {
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

  test('an admin-role account also lands on the merchant dashboard, not the customer home', async () => {
    queueSuccessfulSignIn('admin-1', 'user@example.com');
    mockFakeClient.queueTableResponse('profiles', fakeSupabaseOk({ role: 'admin' }));

    const result = await renderLogin();
    enterCredentials(result, 'user@example.com', 'password123');
    await pressAndSettle(result.getByText('Sign in'));

    expect(router.replace).toHaveBeenCalledWith(AppRoutes.merchantDashboard);
    expect(merchantSessionGate.store.getState().isMerchantRole).toBe(true);
    expect(result.queryByText(/Login failed/)).toBeNull();
  });
});
