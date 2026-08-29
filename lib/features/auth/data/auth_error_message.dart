import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps a caught error from an auth/profile operation into a short,
/// human-readable message that is safe to show in the UI.
///
/// Raw exceptions (in particular [PostgrestException] and other backend
/// errors) can contain internal endpoint, host, or database detail that
/// should never reach a screenshot-able `SnackBar`. This function logs the
/// raw error via [debugPrint] for diagnostics and returns a small, fixed set
/// of user-facing messages instead.
///
/// [context] is a short label (e.g. `'Login'`, `'Registration'`) used only in
/// the debug log line, to make the raw error easier to trace back to its
/// call site.
String describeAuthError(Object error, {required String context}) {
  debugPrint('$context error: $error');

  if (error is AuthException) {
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

  if (error is PostgrestException) {
    return 'We could not save your changes right now. Please try again.';
  }

  return 'Something went wrong. Please check your connection and try again.';
}
