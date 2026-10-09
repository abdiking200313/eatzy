/**
 * Ports the "no-session" branch of `_register` from
 * `flutter_app/lib/features/auth/presentation/register_screen.dart` (issue
 * #366, not literally present in `register_screen_test.dart` as its own
 * case -- that file only exercises the immediate-session path end-to-end --
 * but required by this issue's own acceptance criteria): a sign-up that
 * returns no session (email confirmation required) shows the "Confirm your
 * email" dialog, and tapping its only button navigates to login.
 *
 * RN has no built-in `AlertDialog` equivalent to Flutter's
 * `showDialog`/`AlertDialog` -- `register.tsx` uses the platform
 * `Alert.alert` API instead (see its own doc comment). `Alert.alert` is a
 * no-op under Jest (there is no native `NativeAlertManager` to answer it,
 * so its button callbacks never fire on their own) -- this test spies on
 * `Alert.alert` directly, asserts the exact title/message/button label it
 * was called with, and invokes the captured button's `onPress` itself to
 * simulate the user tapping it.
 *
 * Kept in its own file for the same pre-existing environment reason
 * `login-customer-redirect.test.tsx`'s top comment explains in full -- see
 * `register.test.tsx`'s top comment for what's mocked and why.
 */
import { act, fireEvent, type RenderResult } from '@testing-library/react-native';
import { router } from 'expo-router';
import { Alert } from 'react-native';

import { renderWithProviders } from '@/test-utils';
import { createFakeSupabaseClient, type FakeSupabaseClient } from '@/test-utils/fake-supabase-client';
import { ErrorReporting, NoopErrorReporter, type ErrorReporter } from '@/platform/error-reporting/error-reporter';
import { AppRoutes } from '@/platform/navigation/app-routes';

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

function queueSignUpWithoutSession(userId: string, email: string) {
  const user = {
    id: userId,
    aud: 'authenticated',
    email,
    app_metadata: {},
    user_metadata: {},
    created_at: new Date().toISOString(),
  };
  mockSignUp.mockImplementation(async () => ({ data: { user, session: null }, error: null }));
}

async function renderRegister() {
  return renderWithProviders(<RegisterScreen />);
}

async function fillForm(result: RenderResult, email: string) {
  const { getByPlaceholderText, getByText } = result;
  await fireEvent.changeText(getByPlaceholderText('Jane'), 'Jane');
  await fireEvent.changeText(getByPlaceholderText('Doe'), 'Doe');
  await fireEvent.changeText(getByPlaceholderText('+1 555 123 4567'), '+1 555 123 4567');
  await fireEvent.press(getByPlaceholderText('Select your date of birth'));
  await fireEvent.press(getByText('OK'));
  await fireEvent.changeText(getByPlaceholderText('you@example.com'), email);
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

describe('RegisterScreen -- sign-up with no session (email confirmation required)', () => {
  let previousReporter: ErrorReporter;
  let alertSpy: jest.SpyInstance;

  beforeEach(() => {
    mockFakeClient = createFakeSupabaseClient();
    mockSignUp = jest.fn();
    (router.canGoBack as jest.Mock).mockReturnValue(false);
    previousReporter = ErrorReporting.instance;
    ErrorReporting.instance = new NoopErrorReporter();
    alertSpy = jest.spyOn(Alert, 'alert').mockImplementation(() => {});
  });

  afterEach(() => {
    ErrorReporting.instance = previousReporter;
    alertSpy.mockRestore();
  });

  test('shows the "Confirm your email" dialog, and tapping its button navigates to login', async () => {
    queueSignUpWithoutSession('new-user-id', 'jane@example.com');

    const result = await renderRegister();
    await fillForm(result, 'jane@example.com');
    await pressAndSettle(result.getByText('Create account'));

    expect(router.replace).not.toHaveBeenCalled();
    expect(alertSpy).toHaveBeenCalledTimes(1);
    const [title, message, buttons, options] = alertSpy.mock.calls[0];
    expect(title).toBe('Confirm your email');
    expect(message).toBe(
      'We sent a confirmation link to jane@example.com. Open the link to activate your account, then sign in.',
    );
    expect(buttons).toEqual([{ text: 'Go to sign in', onPress: expect.any(Function) }]);
    expect(options).toEqual({ cancelable: false });
    expect(result.queryByText(/Registration failed/)).toBeNull();

    buttons[0].onPress();

    expect(router.replace).toHaveBeenCalledWith(AppRoutes.login);
  });
});
