/**
 * Ports the "Registration failed: ..." error-message path of `_register`
 * (issue #366): a failed sign-up shows `'Registration failed: '` plus
 * `describeAuthError`'s exact mapped message, never a raw error -- the same
 * invariant `login-invalid-credentials.test.tsx` ports for the sign-in side.
 *
 * Kept in its own file for the same pre-existing environment reason
 * `login-customer-redirect.test.tsx`'s top comment explains in full -- see
 * `register.test.tsx`'s top comment for what's mocked and why.
 */
import { act, fireEvent, type RenderResult } from '@testing-library/react-native';
import { AuthApiError } from '@supabase/supabase-js';
import { router } from 'expo-router';

import { renderWithProviders } from '@/test-utils';
import { createFakeSupabaseClient, type FakeSupabaseClient } from '@/test-utils/fake-supabase-client';
import { ErrorReporting, NoopErrorReporter, type ErrorReporter } from '@/platform/error-reporting/error-reporter';

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

/** Queues a failed sign-up with a *real* `AuthApiError` -- see `login-invalid-credentials.test.tsx`'s own doc comment for why a plain object literal would not do. */
function queueFailedSignUp(code: string, status = 422) {
  mockSignUp.mockImplementation(async () => ({
    data: { user: null, session: null },
    error: new AuthApiError('mock message', status, code),
  }));
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
  await fireEvent.changeText(getByPlaceholderText('you@example.com'), 'existing@example.com');
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

describe('RegisterScreen -- sign-up failure', () => {
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

  test('shows "Registration failed: An account with this email already exists." for a duplicate email', async () => {
    queueFailedSignUp('user_already_exists');

    const result = await renderRegister();
    await fillForm(result);
    await pressAndSettle(result.getByText('Create account'));

    expect(
      result.getByText('Registration failed: An account with this email already exists.'),
    ).toBeOnTheScreen();
    expect(router.replace).not.toHaveBeenCalled();
  });
});
