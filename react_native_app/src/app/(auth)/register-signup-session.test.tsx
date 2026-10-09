/**
 * Ports the "valid input calls signUpWithEmailPassword ... then navigates to
 * the main app with no error message" case from
 * `flutter_app/test/register_screen_test.dart` (issue #366): a sign-up that
 * returns an immediate session (email confirmation disabled) forwards the
 * trimmed field values -- including `dob` as the `yyyy-MM-dd` string
 * `AuthService.signUpWithEmailPassword` builds -- and goes straight to the
 * main app, with no "Registration failed" message.
 *
 * Kept in its own file for the same pre-existing environment reason
 * `login-customer-redirect.test.tsx`'s top comment explains in full -- a
 * real end-to-end "render a fresh `RegisterScreen`, submit, await its async
 * submit chain settling" cycle corrupts a second one sharing the same file
 * under this repo's pinned `react`/`react-reconciler` peer mismatch. See
 * `register.test.tsx`'s top comment for what's mocked and why.
 */
import { act, fireEvent, type RenderResult } from '@testing-library/react-native';
import { router } from 'expo-router';

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
  await fireEvent.changeText(getByPlaceholderText('Jane'), ' Jane ');
  await fireEvent.changeText(getByPlaceholderText('Doe'), ' Doe ');
  await fireEvent.changeText(getByPlaceholderText('+1 555 123 4567'), ' +1 555 123 4567 ');
  await fireEvent.press(getByPlaceholderText('Select your date of birth'));
  await fireEvent.press(getByText('OK'));
  await fireEvent.changeText(getByPlaceholderText('you@example.com'), ' jane@example.com ');
  await fireEvent.changeText(getByPlaceholderText('At least 6 characters'), 'a-strong-password');
  await fireEvent.changeText(getByPlaceholderText('Enter the password again'), 'a-strong-password');
}

/** Presses `element` and settles the screen's fire-and-forget submit chain before returning -- see `login.test.tsx`'s own `pressAndSettle` doc comment for why this needs a trailing real timer tick plus a second `act()` call under this repo's pinned `react`/`react-reconciler` peer mismatch. */
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

describe('RegisterScreen -- sign-up establishes an immediate session', () => {
  let previousReporter: ErrorReporter;

  beforeEach(() => {
    mockFakeClient = createFakeSupabaseClient();
    mockSignUp = jest.fn();
    (router.canGoBack as jest.Mock).mockReturnValue(false);
    previousReporter = ErrorReporting.instance;
    ErrorReporting.instance = new NoopErrorReporter();
  });

  afterEach(() => {
    ErrorReporting.instance = previousReporter;
  });

  test('forwards the trimmed field values (including dob as yyyy-MM-dd) and navigates to the main app with no error message', async () => {
    queueSuccessfulSignUp('new-user-id', 'jane@example.com');
    const now = new Date();
    const expectedDob = new Date(now.getFullYear() - 18, now.getMonth(), now.getDate());
    const expectedDobString = `${expectedDob.getFullYear()}-${String(expectedDob.getMonth() + 1).padStart(2, '0')}-${String(expectedDob.getDate()).padStart(2, '0')}`;

    const result = await renderRegister();
    await fillForm(result);
    await pressAndSettle(result.getByText('Create account'));

    expect(mockSignUp).toHaveBeenCalledWith({
      email: 'jane@example.com',
      password: 'a-strong-password',
      options: {
        data: {
          firstname: 'Jane',
          lastname: 'Doe',
          phone: '+1 555 123 4567',
          dob: expectedDobString,
        },
      },
    });
    expect(router.replace).toHaveBeenCalledWith(AppRoutes.mainApp);
    expect(result.queryByText(/Registration failed/)).toBeNull();
  });
});
