/**
 * Ports "does not show a failed message when navigation throws after a
 * successful sign-up" from `flutter_app/test/register_screen_test.dart`
 * (issue #366): the post-sign-up `router.replace` call sits outside the
 * try/catch around `authService.signUpWithEmailPassword`, so a navigation
 * failure after a *successful* sign-up must never surface as a "Registration
 * failed" message -- see `register.tsx`'s own doc comment and the Dart
 * file's issue #295 comment (the same invariant `login-navigation-
 * error.test.tsx` ports for the sign-in side).
 *
 * As in `login-navigation-error.test.tsx`, `register.tsx`'s submit handler
 * is fire-and-forget but attaches a `.catch` that reports (not silently
 * swallows) a post-success failure via `ErrorReporting` -- see that file's
 * own doc comment for why a true dangling, uncaught rejection (what the
 * Dart test's `runZonedGuarded` reproduces) is not testable under
 * `jest-circus`, and why reporting instead keeps the one invariant this
 * case cares about both true and testable.
 *
 * Kept in its own file for the same pre-existing environment reason
 * `login-customer-redirect.test.tsx`'s top comment explains in full -- see
 * `register.test.tsx`'s top comment for what's mocked and why.
 */
import { act, fireEvent, type RenderResult } from '@testing-library/react-native';
import { router } from 'expo-router';

import { renderWithProviders } from '@/test-utils';
import { createFakeSupabaseClient, type FakeSupabaseClient } from '@/test-utils/fake-supabase-client';
import { ErrorReporting, type ErrorReporter } from '@/platform/error-reporting/error-reporter';

import RegisterScreen from './register';

let mockFakeClient: FakeSupabaseClient;
let mockSignUp: jest.Mock;

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
      signUp: (credentials: unknown) => mockSignUp(credentials),
    },
    from: (table: string) => mockFakeClient.from(table),
  },
}));

jest.mock('@react-native-community/datetimepicker', () => {
  // Jest's mock-factory hoisting forbids referencing an out-of-scope
  // import, so this has to require() lazily inside the factory instead --
  // see dev-gallery.test.tsx's own identical comment.
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { Pressable, Text } = require('react-native');
  return {
    __esModule: true,
    default: ({ value, onChange }: { value: Date; onChange: (event: { type: 'set' }, date: Date) => void }) => (
      <Pressable accessibilityRole="button" onPress={() => onChange({ type: 'set' }, value)}>
        <Text>OK</Text>
      </Pressable>
    ),
  };
});

function queueSuccessfulSignUp(userId: string, email: string) {
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
  mockSignUp.mockImplementation(async () => ({ data: { user, session }, error: null }));
}

async function renderRegister() {
  return renderWithProviders(<RegisterScreen />);
}

async function fillForm(result: RenderResult) {
  const { getByPlaceholderText, getByText } = result;
  await fireEvent.changeText(getByPlaceholderText('Jane'), 'Jane');
  await fireEvent.changeText(getByPlaceholderText('Doe'), 'Doe');
  await fireEvent.changeText(getByPlaceholderText('+1 555 123 4567'), '+1 555 123 4567');
  await fireEvent.press(getByPlaceholderText('Select your date of birth'));
  await fireEvent.press(getByText('OK'));
  await fireEvent.changeText(getByPlaceholderText('you@example.com'), 'jane@example.com');
  await fireEvent.changeText(getByPlaceholderText('At least 6 characters'), 'a-strong-password');
  await fireEvent.changeText(getByPlaceholderText('Enter the password again'), 'a-strong-password');
}

/** See `register-signup-session.test.tsx`'s own `pressAndSettle` doc comment. */
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

describe('RegisterScreen -- navigation throws after a successful sign-up', () => {
  let previousReporter: ErrorReporter;
  let reportError: jest.Mock;

  beforeEach(() => {
    mockFakeClient = createFakeSupabaseClient();
    mockSignUp = jest.fn();
    (router.canGoBack as jest.Mock).mockReturnValue(false);
    previousReporter = ErrorReporting.instance;
    reportError = jest.fn();
    ErrorReporting.instance = { reportError };
  });

  afterEach(() => {
    ErrorReporting.instance = previousReporter;
  });

  test('does not show a failed message when navigation throws after a successful sign-up', async () => {
    queueSuccessfulSignUp('new-user-id', 'jane@example.com');
    const navigationError = new Error('navigation failed');
    (router.replace as jest.Mock).mockImplementation(() => {
      throw navigationError;
    });

    const result = await renderRegister();
    await fillForm(result);
    await pressAndSettle(result.getByText('Create account'));

    expect(router.replace).toHaveBeenCalled();
    // The failure is reported for diagnostics (this app's established
    // `ErrorReporting` convention) rather than swallowed outright or
    // surfaced as a registration failure.
    expect(reportError).toHaveBeenCalledWith(navigationError, navigationError.stack, 'RegisterScreen.handlePress');
    expect(result.queryByText(/Registration failed/)).toBeNull();
  });
});
