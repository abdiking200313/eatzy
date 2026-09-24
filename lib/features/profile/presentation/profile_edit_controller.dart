import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../platform/error_reporting/error_reporter.dart';
import '../../auth/data/auth_error_message.dart';
import '../../auth/data/auth_service.dart';
import '../data/profile_repository.dart';
import '../models/customer_profile.dart';
import '../models/profile_field_validators.dart';

/// The outcome of a `ProfileEditController` update call, mirroring the
/// `FoodCheckoutResult`/`GroceryCheckoutResult` shape used by the checkout
/// controllers.
///
/// [profile] is the saved row for the `updateName`/`updatePhone`/`updateDob`
/// calls (which write to `profiles` directly); it is always `null` for
/// [updateEmail], whose success means only that Supabase accepted the change
/// request — the new address isn't live until the confirmation email is
/// tapped, so there is no updated `profiles` row to return yet.
class ProfileEditResult {
  const ProfileEditResult._({
    required this.isSuccess,
    this.profile,
    this.errors = const [],
  });

  factory ProfileEditResult.success([CustomerProfile? profile]) =>
      ProfileEditResult._(isSuccess: true, profile: profile);

  factory ProfileEditResult.invalid(List<String> errors) =>
      ProfileEditResult._(isSuccess: false, errors: List.unmodifiable(errors));

  final bool isSuccess;
  final CustomerProfile? profile;
  final List<String> errors;
}

/// Owns profile-edit form state (validation, submission, success/error) for
/// the Settings → Account per-field bottom sheets (Name / Phone / Date of
/// birth / Email), mirroring the `FoodController`/`GroceryController`
/// checkout-controller pattern (issue #13).
class ProfileEditController extends ChangeNotifier {
  ProfileEditController({
    ProfileRepository? profileRepository,
    AuthService? authService,
  }) : _profileRepository = profileRepository,
       _authService = authService;

  final ProfileRepository? _profileRepository;
  final AuthService? _authService;

  bool _isSubmitting = false;
  String? _submissionError;
  List<String> _fieldErrors = const [];

  bool get isSubmitting => _isSubmitting;
  String? get submissionError => _submissionError;

  /// Generic validation messages for the current attempt, meant to be
  /// mapped onto field keys by the presentation layer.
  List<String> get fieldErrors => _fieldErrors;

  ProfileRepository get _repository =>
      _profileRepository ??
      SupabaseProfileRepository(client: Supabase.instance.client);

  AuthService get _auth => _authService ?? AuthService();

  static const String _saveFailureMessage =
      'Could not save your profile. Please try again.';

  /// Validates [firstName]/[lastName] and, if valid, writes them to the
  /// current user's own profile row.
  Future<ProfileEditResult> updateName({
    required String firstName,
    required String lastName,
  }) {
    final errors = [
      validateFirstName(firstName),
      validateLastName(lastName),
    ].whereType<String>().toList();
    if (errors.isNotEmpty) {
      return _invalid(errors);
    }

    return _run(
      () => _repository.updateProfile(
        firstName: firstName.trim(),
        lastName: lastName.trim(),
      ),
    );
  }

  /// Validates [phone] and, if valid, writes it to the current user's own
  /// profile row.
  Future<ProfileEditResult> updatePhone(String phone) {
    final error = validatePhone(phone);
    if (error != null) {
      return _invalid([error]);
    }

    return _run(() => _repository.updateProfile(phone: phone.trim()));
  }

  /// Validates [dob] and, if valid, writes it to the current user's own
  /// profile row.
  Future<ProfileEditResult> updateDob(DateTime dob) {
    final error = validateDob(dob);
    if (error != null) {
      return _invalid([error]);
    }

    return _run(() => _repository.updateProfile(dob: dob));
  }

  /// Validates [email] and, if it differs from the signed-in user's current
  /// address, starts an email change via [AuthService.updateEmail].
  ///
  /// Success does not mean the address is live yet — Supabase emails a
  /// confirmation link to the new address first — so [ProfileEditResult] on
  /// success carries no updated profile.
  Future<ProfileEditResult> updateEmail(String email) async {
    final error = validateEmail(email);
    if (error != null) {
      return _invalid([error]);
    }

    final trimmed = email.trim();
    final currentEmail = _auth.getCurrentUserEmail();
    if (currentEmail != null &&
        currentEmail.toLowerCase() == trimmed.toLowerCase()) {
      return _invalid(["That's already your email address."]);
    }

    if (_isSubmitting) {
      return ProfileEditResult.invalid(const []);
    }

    _beginSubmit();
    try {
      await _auth.updateEmail(trimmed);
      _endSubmit();
      return ProfileEditResult.success();
    } on Object catch (error, stack) {
      ErrorReporting.instance.reportError(
        error,
        stack,
        context: 'ProfileEditController.updateEmail',
      );
      final message = describeAuthError(error, context: 'Email update');
      _endSubmit(error: message);
      return ProfileEditResult.invalid([message]);
    }
  }

  Future<ProfileEditResult> _invalid(List<String> errors) async {
    _fieldErrors = errors;
    _submissionError = null;
    notifyListeners();
    return ProfileEditResult.invalid(errors);
  }

  /// Shared submit/error/double-submit-guard plumbing for the three
  /// `profiles`-backed updates ([updateName]/[updatePhone]/[updateDob]).
  Future<ProfileEditResult> _run(
    Future<CustomerProfile> Function() write,
  ) async {
    if (_isSubmitting) {
      return ProfileEditResult.invalid(const []);
    }

    _beginSubmit();
    try {
      final profile = await write();
      _endSubmit();
      return ProfileEditResult.success(profile);
    } on Object catch (error, stack) {
      ErrorReporting.instance.reportError(
        error,
        stack,
        context: 'ProfileEditController.submit',
      );
      _endSubmit(error: _saveFailureMessage);
      return ProfileEditResult.invalid([_saveFailureMessage]);
    }
  }

  void _beginSubmit() {
    _isSubmitting = true;
    _submissionError = null;
    _fieldErrors = const [];
    notifyListeners();
  }

  void _endSubmit({String? error}) {
    _isSubmitting = false;
    _submissionError = error;
    notifyListeners();
  }
}
