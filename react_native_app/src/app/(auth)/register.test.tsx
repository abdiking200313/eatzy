/**
 * Ports `flutter_app/test/register_screen_test.dart`'s basic render cases
 * and its `validation` group (issue #366): every empty/invalid-field check
 * blocks submission with the exact message `_register`'s matching
 * early-return `if` shows, in the exact order those `if`s run (see
 * `register.tsx`'s own top comment for the full ordered list -- this file
 * additionally covers the password-length/email-format/password-mismatch
 * rules the Dart file's own `validation` group doesn't exercise directly,
 * since this issue's acceptance criteria call for every rule in that order,
 * not just the five the Dart suite happens to assert).
 *
 * None of these cases calls `authService.signUpWithEmailPassword` --
 * `onInvalid` rejects the submission before the real sign-up call ever runs
 * -- so, unlike the "successful sign-up"/"email confirmation"/"navigation
 * throws" cases (each in their own sibling file for the pre-existing
 * environment reason `login-customer-redirect.test.tsx`'s top comment
 * explains in full), every case here is safe to share one file: none of
 * them is a real end-to-end "render a fresh `RegisterScreen`, submit, await
 * its async submit chain settling" cycle.
 *
 * `@react-native-community/datetimepicker`'s real native picker has no
 * Jest double and would throw if actually rendered under test -- this
 * mocks it with a trivial `Pressable` labeled "OK" that immediately accepts
 * whatever `value` it was given, mirroring the Flutter test's own
 * `tester.tap(find.text('OK'))` tap on its OS date-picker dialog's default
 * button to accept the initial (eighteen-years-ago) date.
 */
import { fireEvent, type RenderResult } from '@testing-library/react-native';
import { router } from 'expo-router';

import { renderWithProviders } from '@/test-utils';
import { createFakeSupabaseClient, type FakeSupabaseClient } from '@/test-utils/fake-supabase-client';

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

async function renderRegister() {
  return renderWithProviders(<RegisterScreen />);
}

interface FormOverrides {
  firstName?: string;
  lastName?: string;
  phone?: string;
  email?: string;
  password?: string;
  confirmPassword?: string;
}

/** Fills every field with a valid default value, overridable per-field -- mirrors `register_screen_test.dart`'s own `_fillForm` helper. */
async function fillForm(result: RenderResult, overrides: FormOverrides = {}, { skipDob = false } = {}) {
  const { getByPlaceholderText, getByText } = result;
  await fireEvent.changeText(getByPlaceholderText('Jane'), overrides.firstName ?? 'Jane');
  await fireEvent.changeText(getByPlaceholderText('Doe'), overrides.lastName ?? 'Doe');
  await fireEvent.changeText(getByPlaceholderText('+1 555 123 4567'), overrides.phone ?? '+1 555 123 4567');
  if (!skipDob) {
    await fireEvent.press(getByPlaceholderText('Select your date of birth'));
    await fireEvent.press(getByText('OK'));
  }
  await fireEvent.changeText(getByPlaceholderText('you@example.com'), overrides.email ?? 'jane@example.com');
  await fireEvent.changeText(getByPlaceholderText('At least 6 characters'), overrides.password ?? 'a-strong-password');
  await fireEvent.changeText(
    getByPlaceholderText('Enter the password again'),
    overrides.confirmPassword ?? 'a-strong-password',
  );
}

async function submit(result: RenderResult) {
  await fireEvent.press(result.getByText('Create account'));
}

describe('RegisterScreen', () => {
  beforeEach(() => {
    mockFakeClient = createFakeSupabaseClient();
    mockSignUp = jest.fn();
    (router.canGoBack as jest.Mock).mockReturnValue(false);
  });

  afterEach(() => {
    (router.canGoBack as jest.Mock).mockClear();
    (router.back as jest.Mock).mockClear();
    (router.replace as jest.Mock).mockClear();
    (router.push as jest.Mock).mockClear();
  });

  test('renders with the default (singleton-backed) AuthService -- no sign-up exercised', async () => {
    const { getByText } = await renderRegister();

    expect(getByText('Create your account')).toBeOnTheScreen();
  });

  describe('sign-up form', () => {
    test('renders every key field/action', async () => {
      const { getByText } = await renderRegister();

      expect(getByText('Create your account')).toBeOnTheScreen();
      expect(getByText('First name')).toBeOnTheScreen();
      expect(getByText('Last name')).toBeOnTheScreen();
      expect(getByText('Phone number')).toBeOnTheScreen();
      expect(getByText('Date of birth')).toBeOnTheScreen();
      expect(getByText('Email address')).toBeOnTheScreen();
      expect(getByText('Password')).toBeOnTheScreen();
      expect(getByText('Confirm password')).toBeOnTheScreen();
      expect(getByText('Create account')).toBeOnTheScreen();
    });
  });

  describe('validation', () => {
    test('blocks submission when first name is empty', async () => {
      const result = await renderRegister();

      await fillForm(result, { firstName: '' });
      await submit(result);

      expect(result.getByText('Please fill in every field.')).toBeOnTheScreen();
      expect(mockSignUp).not.toHaveBeenCalled();
    });

    test('blocks submission when last name is empty', async () => {
      const result = await renderRegister();

      await fillForm(result, { lastName: '' });
      await submit(result);

      expect(result.getByText('Please fill in every field.')).toBeOnTheScreen();
      expect(mockSignUp).not.toHaveBeenCalled();
    });

    test('blocks submission when phone is empty', async () => {
      const result = await renderRegister();

      await fillForm(result, { phone: '' });
      await submit(result);

      expect(result.getByText('Please fill in every field.')).toBeOnTheScreen();
      expect(mockSignUp).not.toHaveBeenCalled();
    });

    test('blocks submission when date of birth is not selected', async () => {
      const result = await renderRegister();

      await fillForm(result, {}, { skipDob: true });
      await submit(result);

      expect(result.getByText('Please fill in every field.')).toBeOnTheScreen();
      expect(mockSignUp).not.toHaveBeenCalled();
    });

    test('blocks submission with a validation message for a too-short password', async () => {
      const result = await renderRegister();

      await fillForm(result, { password: '12345', confirmPassword: '12345' });
      await submit(result);

      expect(result.getByText('Password must be at least 6 characters.')).toBeOnTheScreen();
      expect(mockSignUp).not.toHaveBeenCalled();
    });

    test('blocks submission with a validation message for an invalid email address', async () => {
      const result = await renderRegister();

      await fillForm(result, { email: 'not-an-email' });
      await submit(result);

      expect(result.getByText('Please enter a valid email address.')).toBeOnTheScreen();
      expect(mockSignUp).not.toHaveBeenCalled();
    });

    test('blocks submission with a validation message for an invalid phone number', async () => {
      const result = await renderRegister();

      await fillForm(result, { phone: 'not-a-number' });
      await submit(result);

      expect(result.getByText('Please enter a valid phone number.')).toBeOnTheScreen();
      expect(mockSignUp).not.toHaveBeenCalled();
    });

    test('blocks submission with a validation message when passwords do not match', async () => {
      const result = await renderRegister();

      await fillForm(result, { confirmPassword: 'a-different-password' });
      await submit(result);

      expect(result.getByText('Passwords do not match.')).toBeOnTheScreen();
      expect(mockSignUp).not.toHaveBeenCalled();
    });
  });
});
