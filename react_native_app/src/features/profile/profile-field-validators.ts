/**
 * Ports `flutter_app/lib/features/profile/models/profile_field_validators.dart`
 * (issue #400 / P8-04): pure field-level validators for the Settings →
 * Account edit sheets, mirroring the rules `register.tsx` applies at account
 * creation so a customer can change these fields later but never clear them.
 *
 * Each returns the user-facing error message, or `null` when valid. The
 * messages double as the keys `EditFieldSheet` matches to place an error
 * under the right field, so they must stay byte-identical to Flutter's.
 */

/** Same pattern as `register.tsx`'s `PHONE_REGEX` and the Dart `_phoneRegExp`. */
const PHONE_REGEX = /^\+?[0-9\s-]{7,15}$/;

/** Same pattern as the Dart `_emailRegExp`. */
const EMAIL_REGEX = /^[a-zA-Z0-9.!#$%&'*+\-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+$/;

export function validateFirstName(value: string): string | null {
  return value.trim() === '' ? 'Enter your first name.' : null;
}

export function validateLastName(value: string): string | null {
  return value.trim() === '' ? 'Enter your last name.' : null;
}

export function validatePhone(value: string): string | null {
  const trimmed = value.trim();
  if (trimmed === '') return 'Enter your phone number.';
  if (!PHONE_REGEX.test(trimmed)) return 'Please enter a valid phone number.';
  return null;
}

export function validateDob(value: Date | null | undefined): string | null {
  if (value == null) return 'Choose your date of birth.';
  if (value.getTime() > Date.now()) return "Date of birth can't be in the future.";
  return null;
}

export function validateEmail(value: string): string | null {
  const trimmed = value.trim();
  if (trimmed === '') return 'Enter your email address.';
  if (!EMAIL_REGEX.test(trimmed)) return 'Please enter a valid email address.';
  return null;
}
