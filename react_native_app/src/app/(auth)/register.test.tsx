/**
 * Ports `flutter_app/test/register_screen_test.dart` (issue #366): the
 * render cases, every distinct validation message in `register.tsx`'s
 * sequential check order, a valid sign-up (trimmed fields, exact metadata
 * shape, `dob` as `yyyy-MM-dd`), the session-less (email-confirmation-
 * required) branch, and a sign-up failure.
 *
 * Two Dart cases are deliberately not ported:
 *  - "does not overflow at 320x640 with a 1.4x text scale" has no RNTL
 *    equivalent (no real layout/overflow detection under Jest's Node
 *    environment) -- this is a layout-only concern, out of this port's
 *    scope.
 *  - "does not show a failed message when navigation throws after a
 *    successful sign-up" relies on Dart's `GoRouter`-less `MaterialApp`
 *    throwing on `context.go` and a `runZonedGuarded` catch -- this app's
 *    `router.replace` is an imperative `expo-router` mock (see below) that
 *    never throws, so there is nothing to reproduce; `handlePress`'s own
 *    generic `ErrorReporting.instance.reportError` catch-all (shared with
 *    `login.tsx`, already covered by that file's own structure) is this
 *    app's equivalent safety net.
 * Dart's "renders using the AppScope-backed default AuthService when none
 * is injected" case maps to this file's "renders with the default
 * (singleton-backed) AuthService" case below, mirroring
 * `login.test.tsx`'s own first test for the same reason: this screen never
 * takes an injected `authService` prop, so every test here already
 * exercises the real default singleton.
 *
 * `expo-router`'s imperative `router` is mocked the same way
 * `login.test.tsx` mocks it -- `register.tsx` only ever calls
 * `router.replace`/`router.back`/`router.canGoBack` (never `router.push`,
 * unlike `login.tsx`, so that mock is omitted here).
 *
 * `@/platform/supabase/client`'s `supabase` export is replaced with a fake
 * exposing only `auth.signUp` -- unlike `login.test.tsx`'s mock, no
 * `from(...)` fake is needed: `register.tsx`'s post-sign-up path never
 * queries a table (no merchant-role lookup), it branches on
 * `response.session` alone.
 *
 * `@react-native-community/datetimepicker` is mocked at the module level
 * (both the default `DateTimePicker` component used on the screen's iOS
 * branch and the imperative `DateTimePickerAndroid.open` used on its
 * Android branch) so a fixed date can be injected without driving a real
 * native picker -- RNTL has no way to simulate one. Both mocked entry
 * points funnel into the same captured `onValueChange`, so `selectDob`
 * below works regardless of which branch `Platform.OS` resolves to under
 * Jest.
 */
import { act, fireEvent, type RenderResult } from '@testing-library/react-native';
import { router } from 'expo-router';
import { Alert } from 'react-native';

import { renderWithProviders } from '@/test-utils';
import { ErrorReporting, NoopErrorReporter, type ErrorReporter } from '@/platform/error-reporting/error-reporter';
import { AppRoutes } from '@/platform/navigation/app-routes';

import RegisterScreen from './register';

let mockSignUp: jest.Mock;
let mockDateTimePickerOnValueChange: ((event: unknown, date?: Date) => void) | undefined;

jest.mock('expo-router', () => ({
  router: {
    canGoBack: jest.fn(() => false),
    back: jest.fn(),
    replace: jest.fn(),
  },
}));

// `auth-service.ts`'s default `AuthService` resolves its Supabase
// dependency from this module -- see this file's top comment.
jest.mock('@/platform/supabase/client', () => ({
  supabase: {
    auth: {
      signUp: (credentials: unknown) => mockSignUp(credentials),
    },
  },
}));

jest.mock('@react-native-community/datetimepicker', () => ({
  __esModule: true,
  default: (props: { onValueChange?: (event: unknown, date?: Date) => void }) => {
    mockDateTimePickerOnValueChange = props.onValueChange;
    return null;
  },
  DateTimePickerAndroid: {
    open: (options: { onValueChange?: (event: unknown, date?: Date) => void }) => {
      mockDateTimePickerOnValueChange = options.onValueChange;
    },
  },
}));

const FIXED_DOB = new Date('1990-06-15T12:00:00Z');

function supabaseUser(userId: string, email: string) {
  return {
    id: userId,
    aud: 'authenticated',
    email,
    app_metadata: {},
    user_metadata: {},
    created_at: new Date().toISOString(),
  };
}

function queueSignUpResponse(userId: string, email: string, hasSession: boolean) {
  const user = supabaseUser(userId, email);
  const session = hasSession
    ? {
        access_token: 'mock-access-token',
        refresh_token: 'mock-refresh-token',
        expires_in: 3600,
        token_type: 'bearer',
        user,
      }
    : null;
  mockSignUp.mockResolvedValue({ data: { user, session }, error: null });
}

async function renderRegister() {
  return renderWithProviders(<RegisterScreen />);
}

/** Opens the date-of-birth field and invokes the mocked picker's `onValueChange` with `date` -- see this file's top comment. */
async function selectDob({ getByPlaceholderText }: RenderResult, date: Date) {
  await fireEvent.press(getByPlaceholderText('Select your date of birth'));
  await act(async () => {
    mockDateTimePickerOnValueChange?.(undefined, date);
  });
}

/**
 * Fills every field except the ones named in `skip`, mirroring
 * `register_screen_test.dart`'s `_fillForm`.
 *
 * Every `fireEvent.changeText` here is awaited -- `fireEvent`'s own
 * implementation (`@testing-library/react-native/dist/events/fire-
 * event.js`) is itself `async` (it wraps the handler call in `act()`
 * internally); leaving one of these un-awaited queues a dangling `act()`
 * that can resolve mid-flight during a *later* test's `render()` in this
 * environment's `react`/`react-reconciler` peer-version mismatch (see
 * `pressAndSettle`'s own doc comment below), observed directly here as an
 * unrelated subsequent test's `render()` committing an empty tree.
 */
async function fillForm(result: RenderResult, { skip = new Set<string>(), phone = '+1 555 123 4567' } = {}) {
  const { getByPlaceholderText } = result;
  if (!skip.has('firstName')) await fireEvent.changeText(getByPlaceholderText('Jane'), 'Jane');
  if (!skip.has('lastName')) await fireEvent.changeText(getByPlaceholderText('Doe'), 'Doe');
  if (!skip.has('phone')) await fireEvent.changeText(getByPlaceholderText('+1 555 123 4567'), phone);
  if (!skip.has('dob')) await selectDob(result, FIXED_DOB);
  if (!skip.has('email')) await fireEvent.changeText(getByPlaceholderText('you@example.com'), 'jane@example.com');
  if (!skip.has('password')) {
    await fireEvent.changeText(getByPlaceholderText('At least 6 characters'), 'a-strong-password');
  }
  if (!skip.has('confirmPassword')) {
    await fireEvent.changeText(getByPlaceholderText('Enter the password again'), 'a-strong-password');
  }
}

/**
 * Presses `element` and settles the screen's fire-and-forget submit chain
 * (sign-up, then the session-branch navigation/alert) before returning.
 *
 * Copied verbatim from `login.test.tsx` -- see that file's own doc comment
 * on this helper for why draining only microtasks inside one `act()` isn't
 * enough under this environment's `react`/`react-reconciler` peer-version
 * mismatch.
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

describe('RegisterScreen', () => {
  let previousReporter: ErrorReporter;

  beforeEach(() => {
    mockSignUp = jest.fn();
    mockDateTimePickerOnValueChange = undefined;
    (router.canGoBack as jest.Mock).mockReturnValue(false);
    // Keeps describeAuthError's deliberate `ErrorReporting.instance.
    // reportError` side effect from spamming the test output -- mirrors
    // `login.test.tsx`'s own posture.
    previousReporter = ErrorReporting.instance;
    ErrorReporting.instance = new NoopErrorReporter();
  });

  afterEach(() => {
    ErrorReporting.instance = previousReporter;
    (router.canGoBack as jest.Mock).mockClear();
    (router.back as jest.Mock).mockClear();
    (router.replace as jest.Mock).mockClear();
    jest.restoreAllMocks();
  });

  test('renders with the default (singleton-backed) AuthService -- no sign-up exercised', async () => {
    const { getByText } = await renderRegister();

    expect(getByText('Create your account')).toBeOnTheScreen();
  });

  test('renders the sign-up form', async () => {
    const { getByText } = await renderRegister();

    expect(getByText('Create your account')).toBeOnTheScreen();
    expect(getByText('Email address')).toBeOnTheScreen();
    expect(getByText('Password')).toBeOnTheScreen();
    expect(getByText('Confirm password')).toBeOnTheScreen();
    expect(getByText('Create account')).toBeOnTheScreen();
  });

  describe('validation', () => {
    test('blocks submission when first name is empty', async () => {
      const result = await renderRegister();

      await fillForm(result, { skip: new Set(['firstName']) });
      await pressAndSettle(result.getByText('Create account'));

      expect(result.getByText('Please fill in every field.')).toBeOnTheScreen();
      expect(mockSignUp).not.toHaveBeenCalled();
    });

    test('blocks submission when last name is empty', async () => {
      const result = await renderRegister();

      await fillForm(result, { skip: new Set(['lastName']) });
      await pressAndSettle(result.getByText('Create account'));

      expect(result.getByText('Please fill in every field.')).toBeOnTheScreen();
      expect(mockSignUp).not.toHaveBeenCalled();
    });

    test('blocks submission when phone is empty', async () => {
      const result = await renderRegister();

      await fillForm(result, { skip: new Set(['phone']) });
      await pressAndSettle(result.getByText('Create account'));

      expect(result.getByText('Please fill in every field.')).toBeOnTheScreen();
      expect(mockSignUp).not.toHaveBeenCalled();
    });

    test('blocks submission when date of birth is not selected', async () => {
      const result = await renderRegister();

      await fillForm(result, { skip: new Set(['dob']) });
      await pressAndSettle(result.getByText('Create account'));

      expect(result.getByText('Please fill in every field.')).toBeOnTheScreen();
      expect(mockSignUp).not.toHaveBeenCalled();
    });

    test('blocks submission with a validation message for a short password', async () => {
      const result = await renderRegister();

      await fillForm(result);
      await fireEvent.changeText(result.getByPlaceholderText('At least 6 characters'), 'abc');
      await fireEvent.changeText(result.getByPlaceholderText('Enter the password again'), 'abc');
      await pressAndSettle(result.getByText('Create account'));

      expect(result.getByText('Password must be at least 6 characters.')).toBeOnTheScreen();
      expect(mockSignUp).not.toHaveBeenCalled();
    });

    test('blocks submission with a validation message for an invalid phone number', async () => {
      const result = await renderRegister();

      await fillForm(result, { phone: 'not-a-number' });
      await pressAndSettle(result.getByText('Create account'));

      expect(result.getByText('Please enter a valid phone number.')).toBeOnTheScreen();
      expect(mockSignUp).not.toHaveBeenCalled();
    });
  });

  test('valid input calls signUp with the trimmed field values and the right metadata, then navigates to the main app with no error message', async () => {
    queueSignUpResponse('new-user-id', 'jane@example.com', true);
    const result = await renderRegister();

    await fireEvent.changeText(result.getByPlaceholderText('Jane'), ' Jane ');
    await fireEvent.changeText(result.getByPlaceholderText('Doe'), ' Doe ');
    await fireEvent.changeText(result.getByPlaceholderText('+1 555 123 4567'), ' +1 555 123 4567 ');
    await selectDob(result, FIXED_DOB);
    await fireEvent.changeText(result.getByPlaceholderText('you@example.com'), ' jane@example.com ');
    await fireEvent.changeText(result.getByPlaceholderText('At least 6 characters'), 'a-strong-password');
    await fireEvent.changeText(result.getByPlaceholderText('Enter the password again'), 'a-strong-password');

    await pressAndSettle(result.getByText('Create account'));

    expect(mockSignUp).toHaveBeenCalledWith({
      email: 'jane@example.com',
      password: 'a-strong-password',
      options: {
        data: {
          firstname: 'Jane',
          lastname: 'Doe',
          phone: '+1 555 123 4567',
          dob: '1990-06-15',
        },
      },
    });
    expect(router.replace).toHaveBeenCalledWith(AppRoutes.mainApp);
    expect(result.queryByText(/Registration failed/)).toBeNull();
  });

  test('a session-less sign-up response shows the "confirm your email" dialog instead of navigating', async () => {
    const alertSpy = jest.spyOn(Alert, 'alert').mockImplementation(() => {});
    queueSignUpResponse('new-user-id', 'jane@example.com', false);
    const result = await renderRegister();

    await fillForm(result);
    await pressAndSettle(result.getByText('Create account'));

    expect(alertSpy).toHaveBeenCalledWith(
      'Confirm your email',
      'We sent a confirmation link to jane@example.com. Open the link to activate your account, then sign in.',
      expect.anything(),
    );
    expect(router.replace).not.toHaveBeenCalledWith(AppRoutes.mainApp);
  });

  test('shows a "Registration failed" message when sign-up fails, without navigating', async () => {
    mockSignUp.mockResolvedValue({ data: { user: null, session: null }, error: new Error('boom') });
    const result = await renderRegister();

    await fillForm(result);
    await pressAndSettle(result.getByText('Create account'));

    expect(
      result.getByText('Registration failed: Something went wrong. Please check your connection and try again.'),
    ).toBeOnTheScreen();
    expect(router.replace).not.toHaveBeenCalled();
  });
});
