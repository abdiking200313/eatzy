/**
 * Ports the mapping-table coverage implied by
 * `flutter_app/lib/features/auth/data/auth_error_message.dart`'s
 * `describeAuthError` (issue #365) -- there is no standalone
 * `auth_error_message_test.dart` on the Flutter side (its behavior is only
 * exercised indirectly through `login_screen_test.dart`'s error-message
 * assertions), so this is a direct unit-test of the ported function and its
 * exact code -> message table instead.
 */
import { AuthApiError, AuthRetryableFetchError, PostgrestError } from '@supabase/supabase-js';

import { ErrorReporting, NoopErrorReporter, type ErrorReporter } from '@/platform/error-reporting/error-reporter';

import { describeAuthError } from './auth-error-message';

describe('describeAuthError', () => {
  let reporter: ErrorReporter;
  let previousReporter: ErrorReporter;

  beforeEach(() => {
    previousReporter = ErrorReporting.instance;
    reporter = { reportError: jest.fn() };
    ErrorReporting.instance = reporter;
  });

  afterEach(() => {
    ErrorReporting.instance = previousReporter;
  });

  test.each([
    ['invalid_credentials', 'Incorrect email or password.'],
    ['email_not_confirmed', 'Please confirm your email address before signing in.'],
    ['user_already_exists', 'An account with this email already exists.'],
    ['email_exists', 'An account with this email already exists.'],
    ['weak_password', 'Please choose a stronger password.'],
    ['same_password', 'That is your current password. Please choose a new one.'],
    ['user_not_found', 'No account was found for this email.'],
    ['over_email_send_rate_limit', 'Too many attempts. Please wait a moment and try again.'],
    ['over_request_rate_limit', 'Too many attempts. Please wait a moment and try again.'],
    ['signup_disabled', 'New sign-ups are not available right now.'],
    ['some_unmapped_code', 'We could not complete that request. Please try again.'],
  ])('maps AuthApiError code %s to %s', (code, expected) => {
    const error = new AuthApiError('mock message', 400, code);

    expect(describeAuthError(error, 'Login')).toBe(expected);
  });

  test('maps a non-AuthApiError AuthError (e.g. a retryable fetch failure) to the generic fallback', () => {
    const error = new AuthRetryableFetchError('network error', 0);

    expect(describeAuthError(error, 'Login')).toBe('We could not complete that request. Please try again.');
  });

  test('maps a PostgrestError to its own generic message', () => {
    const error = new PostgrestError({
      message: 'permission denied',
      details: '',
      hint: '',
      code: '42501',
    });

    expect(describeAuthError(error, 'Login')).toBe('We could not save your changes right now. Please try again.');
  });

  test('maps any other error to the fully generic fallback', () => {
    expect(describeAuthError('boom', 'Login')).toBe(
      'Something went wrong. Please check your connection and try again.',
    );
    expect(describeAuthError(new Error('boom'), 'Login')).toBe(
      'Something went wrong. Please check your connection and try again.',
    );
  });

  test('reports the raw error via ErrorReporting with the given context', () => {
    const error = new AuthApiError('mock message', 400, 'invalid_credentials');

    describeAuthError(error, 'Login');

    expect(reporter.reportError).toHaveBeenCalledWith(error, error.stack, 'Login');
  });

  test('does not throw when ErrorReporting is a no-op (defensive -- mirrors other call sites)', () => {
    ErrorReporting.instance = new NoopErrorReporter();

    expect(() => describeAuthError(new Error('boom'), 'Login')).not.toThrow();
  });
});
