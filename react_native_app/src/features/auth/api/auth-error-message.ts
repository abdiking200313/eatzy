/**
 * Ports `flutter_app/lib/features/auth/data/auth_error_message.dart`'s
 * `describeAuthError` (issue #365).
 *
 * Maps a caught sign-in error into a short, fixed, user-facing string --
 * never the raw error, which can carry internal endpoint/host/database
 * detail that should never reach a screenshot-able UI message. The raw
 * error is still reported via `ErrorReporting` first, for diagnostics.
 */
import { isAuthError, PostgrestError } from '@supabase/supabase-js';

import { ErrorReporting } from '@/platform/error-reporting/error-reporter';

/**
 * Mirrors `describeAuthError(Object error, {required String context,
 * StackTrace? stackTrace})`. `stackTrace` isn't a separate parameter here --
 * this follows this codebase's own `ErrorReporting.instance.reportError`
 * call pattern instead (see e.g. `onboarding-store.ts`), deriving the stack
 * from `error` itself when it's an `Error`.
 *
 * `context` is a short label (e.g. `'Login'`) used only in the error
 * report, to make the raw error easier to trace back to its call site.
 */
export function describeAuthError(error: unknown, context: string): string {
  ErrorReporting.instance.reportError(error, error instanceof Error ? error.stack : undefined, context);

  if (isAuthError(error)) {
    switch (error.code) {
      case 'invalid_credentials':
        return 'Incorrect email or password.';
      case 'email_not_confirmed':
        return 'Please confirm your email address before signing in.';
      case 'user_already_exists':
      case 'email_exists':
        return 'An account with this email already exists.';
      case 'weak_password':
        return 'Please choose a stronger password.';
      case 'same_password':
        return 'That is your current password. Please choose a new one.';
      case 'user_not_found':
        return 'No account was found for this email.';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'signup_disabled':
        return 'New sign-ups are not available right now.';
      default:
        return 'We could not complete that request. Please try again.';
    }
  }

  if (error instanceof PostgrestError) {
    return 'We could not save your changes right now. Please try again.';
  }

  return 'Something went wrong. Please check your connection and try again.';
}
