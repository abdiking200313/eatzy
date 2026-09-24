/// Pure field-level validators shared by profile-edit flows (issue: the
/// standalone Edit Profile screen is being replaced by per-field bottom
/// sheets off Settings), mirroring the rules `register_screen.dart` applies
/// at account creation time so a customer can change these fields later but
/// never clear them.
library;

final RegExp _phoneRegExp = RegExp(r'^\+?[0-9\s-]{7,15}$');

final RegExp _emailRegExp = RegExp(
  r"^[a-zA-Z0-9.!#$%&'*+\-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+$",
);

String? validateFirstName(String value) {
  if (value.trim().isEmpty) {
    return 'Enter your first name.';
  }
  return null;
}

String? validateLastName(String value) {
  if (value.trim().isEmpty) {
    return 'Enter your last name.';
  }
  return null;
}

String? validatePhone(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'Enter your phone number.';
  }
  if (!_phoneRegExp.hasMatch(trimmed)) {
    return 'Please enter a valid phone number.';
  }
  return null;
}

String? validateDob(DateTime? value) {
  if (value == null) {
    return 'Choose your date of birth.';
  }
  if (value.isAfter(DateTime.now())) {
    return "Date of birth can't be in the future.";
  }
  return null;
}

String? validateEmail(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'Enter your email address.';
  }
  if (!_emailRegExp.hasMatch(trimmed)) {
    return 'Please enter a valid email address.';
  }
  return null;
}
