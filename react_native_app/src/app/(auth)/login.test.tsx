/**
 * Ports `flutter_app/test/login_screen_test.dart` (issue #365): the basic
 * render cases, the empty-field validation message, and one "merchant
 * redirect after sign-in" case (a `merchant`-role account lands on the
 * merchant dashboard). The remaining "merchant redirect" cases (customer
 * role, invalid credentials, navigation-throws-after-success) are each in
 * their own sibling file -- see `login-customer-redirect.test.tsx`'s top
 * comment for why this issue's own test suite is split across files
 * instead of one `describe` block the way `login_screen_test.dart` has it.
 *
 * `expo-router`'s imperative `router` is mocked directly the same way
 * `app-scaffold.test.tsx` mocks it -- `login.tsx` only ever calls the
 * imperative `router.replace`/`router.push`/`router.back`/`router.canGoBack`
 * (never `useRouter()`/`<Link>`), so no real route tree is needed under
 * test. `@/platform/supabase/client`'s `supabase` export is replaced with a
 * fake combining `auth.signInWithPassword` with `src/test-utils/fake-
 * supabase-client.ts`'s `from(...)` fake -- the same mocked Supabase client
 * then backs the *real* `AuthService`/`MerchantRoleService`/
 * `MerchantSessionGate` singletons `login.tsx` actually imports, exactly
 * mirroring the Dart test's one mocked HTTP client backing both
 * `AuthService` and `MerchantRoleService` (`clientWithRole`).
 * `auth.onAuthStateChange` is a no-op here (never fires `SIGNED_IN`) -- the
 * session store's own reactive redirect-gate side of this machinery already
 * has its dedicated coverage in `merchant-redirect.test.tsx`, and this
 * issue's own scope is `login.tsx`'s *explicit* `resolveFor` + navigate
 * call, not that reactive path.
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

// `merchant-role-service.ts`'s default `MerchantRoleService` and
// `auth-service.ts`'s default `AuthService` both resolve their Supabase
// dependency from this module -- see this file's top comment.
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

/**
 * Presses `element` and settles the screen's fire-and-forget submit chain
 * (sign-in, the merchant-role lookup, the redirect) before returning.
 *
 * Draining only microtasks (`await Promise.resolve()` in a loop) inside one
 * `act()` call is not enough here: this environment's pinned `react`
 * (`19.2.3`) does not satisfy `test-renderer`'s bundled `react-
 * reconciler@0.34.0`'s own peer requirement (`react@^19.3.0`) -- `npm
 * install` prints this exact conflict, pre-existing in `package-lock.json`
 * before this issue's own changes -- and under that mismatch a state
 * update scheduled only across microtask turns can be left uncommitted:
 * `setMessage` genuinely runs (confirmed by instrumenting `login.tsx`
 * directly while diagnosing this) but the resulting text never reaches the
 * rendered tree. A trailing real (macrotask) timer tick, plus a second,
 * separate `act()` call afterwards to force that pending commit through,
 * reliably fixes it. Fixing the underlying version mismatch is a repo-wide
 * dependency change outside this issue's scope.
 */
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

describe('LoginScreen', () => {
  let previousReporter: ErrorReporter;

  beforeEach(() => {
    mockFakeClient = createFakeSupabaseClient();
    mockSignInWithPassword = jest.fn();
    (router.canGoBack as jest.Mock).mockReturnValue(false);
    useSessionStore.setState({ status: 'signedOut', session: null, userId: null });
    merchantSessionGate.reset();
    // Keeps describeAuthError's deliberate `ErrorReporting.instance.
    // reportError` side effect from spamming the test output -- mirrors
    // `auth-error-message.test.ts`'s own posture.
    previousReporter = ErrorReporting.instance;
    ErrorReporting.instance = new NoopErrorReporter();
  });

  afterEach(() => {
    ErrorReporting.instance = previousReporter;
    (router.canGoBack as jest.Mock).mockClear();
    (router.back as jest.Mock).mockClear();
    (router.replace as jest.Mock).mockClear();
    (router.push as jest.Mock).mockClear();
  });

  test('renders with the default (singleton-backed) AuthService -- no sign-in exercised', async () => {
    const { getByText } = await renderLogin();

    expect(getByText('Welcome back')).toBeOnTheScreen();
  });

  describe('sign-in form', () => {
    test('renders every key field/action', async () => {
      const { getByText } = await renderLogin();

      expect(getByText('Welcome back')).toBeOnTheScreen();
      expect(getByText('Email address')).toBeOnTheScreen();
      expect(getByText('Password')).toBeOnTheScreen();
      expect(getByText('Sign in')).toBeOnTheScreen();
    });

    test('shows a combined message for empty email/password, with no per-field text', async () => {
      const { getByText, queryByText } = await renderLogin();

      await pressAndSettle(getByText('Sign in'));

      expect(getByText('Enter your email and password.')).toBeOnTheScreen();
      expect(mockSignInWithPassword).not.toHaveBeenCalled();
      expect(queryByText(/required/i)).toBeNull();
    });
  });

  // Exercised end-to-end through the login screen's own sign-in form (no
  // second merchant sign-in UI): after a successful sign-in, a
  // `merchant`/`admin` `profiles.role` lands on the merchant dashboard
  // route instead of the customer home. `isAuthorizedMerchantRole`'s own
  // `merchant`-vs-`admin`-vs-`customer` mapping is already exhaustively
  // unit-tested in `merchant-role-service.test.ts` -- this is this file's
  // one end-to-end check that `login.tsx` itself wires that lookup's
  // *result* to the right redirect.
  test('a merchant-role account lands on the merchant dashboard, not the customer home', async () => {
    queueSuccessfulSignIn('merchant-1', 'user@example.com');
    mockFakeClient.queueTableResponse('profiles', fakeSupabaseOk({ role: 'merchant' }));

    const result = await renderLogin();
    enterCredentials(result, 'user@example.com', 'password123');
    await pressAndSettle(result.getByText('Sign in'));

    expect(router.replace).toHaveBeenCalledWith(AppRoutes.merchantDashboard);
    expect(merchantSessionGate.store.getState().isMerchantRole).toBe(true);
    expect(result.queryByText(/Login failed/)).toBeNull();
  });
});
