import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../platform/error_reporting/error_reporter.dart';
import '../data/profile_repository.dart';
import '../models/customer_profile.dart';

/// The outcome of [ProfileEditController.submit], mirroring the
/// `FoodCheckoutResult`/`GroceryCheckoutResult` shape used by the checkout
/// controllers.
class ProfileEditResult {
  const ProfileEditResult._({
    required this.isSuccess,
    this.profile,
    this.errors = const [],
  });

  factory ProfileEditResult.success(CustomerProfile profile) =>
      ProfileEditResult._(isSuccess: true, profile: profile);

  factory ProfileEditResult.invalid(List<String> errors) =>
      ProfileEditResult._(isSuccess: false, errors: List.unmodifiable(errors));

  final bool isSuccess;
  final CustomerProfile? profile;
  final List<String> errors;
}

/// Owns profile-edit form state (validation, submission, success/error),
/// mirroring the `FoodController`/`GroceryController` checkout-controller
/// pattern (issue #13) instead of leaving no write path for the profile at
/// all.
class ProfileEditController extends ChangeNotifier {
  ProfileEditController({ProfileRepository? profileRepository})
    : _profileRepository = profileRepository;

  final ProfileRepository? _profileRepository;

  bool _isSubmitting = false;
  String? _submissionError;
  List<String> _fieldErrors = const [];

  bool get isSubmitting => _isSubmitting;
  String? get submissionError => _submissionError;

  /// Generic validation messages for the current attempt (matching
  /// `FoodController.addressErrors`'s shape), meant to be mapped onto field
  /// keys by the presentation layer — see `_profileFieldErrors` in
  /// `edit_profile_screen.dart`.
  List<String> get fieldErrors => _fieldErrors;

  ProfileRepository get _repository =>
      _profileRepository ??
      SupabaseProfileRepository(client: Supabase.instance.client);

  /// Validates [firstName]/[lastName]/[phone] and, if valid, writes them to
  /// the current user's own profile row via
  /// [ProfileRepository.updateProfile].
  ///
  /// A second call while one is already in flight is a no-op returning an
  /// empty invalid result, matching `FoodController.confirmOrder`'s
  /// double-submit guard.
  Future<ProfileEditResult> submit({
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    if (_isSubmitting) {
      return ProfileEditResult.invalid(const []);
    }

    final errors = _validate(firstName, lastName, phone);
    if (errors.isNotEmpty) {
      _fieldErrors = errors;
      _submissionError = null;
      notifyListeners();
      return ProfileEditResult.invalid(errors);
    }

    _isSubmitting = true;
    _submissionError = null;
    _fieldErrors = const [];
    notifyListeners();

    try {
      final profile = await _repository.updateProfile(
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        phone: phone.trim(),
      );
      _isSubmitting = false;
      notifyListeners();
      return ProfileEditResult.success(profile);
    } on Object catch (error, stack) {
      ErrorReporting.instance.reportError(
        error,
        stack,
        context: 'ProfileEditController.submit',
      );
      _isSubmitting = false;
      _submissionError = 'Could not save your profile. Please try again.';
      notifyListeners();
      return ProfileEditResult.invalid([_submissionError!]);
    }
  }

  List<String> _validate(String firstName, String lastName, String phone) {
    final errors = <String>[];
    if (firstName.trim().isEmpty) {
      errors.add('Enter your first name.');
    }
    if (lastName.trim().isEmpty) {
      errors.add('Enter your last name.');
    }
    // Phone is optional (the `profiles.phone` column is nullable) — only
    // validated when the customer entered something, mirroring how
    // `FoodController._validateAddress` treats its always-required phone
    // but relaxed for optionality here.
    final trimmedPhone = phone.trim();
    if (trimmedPhone.isNotEmpty && trimmedPhone.length < 7) {
      errors.add('Enter a valid phone number.');
    }
    return errors;
  }
}
