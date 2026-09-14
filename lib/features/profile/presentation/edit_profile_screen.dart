import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/theme.dart';
import '../../../platform/error_reporting/error_reporter.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_scaffold.dart';
import '../data/profile_repository.dart';
import '../models/customer_profile.dart';
import 'profile_edit_controller.dart';

/// Rounded outline border matching `DeliveryAddressCard`'s field style, so
/// this form reads as the same app-wide input pattern.
final _fieldBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(TwRadius.xl),
);

/// Maps [ProfileEditController.fieldErrors]' generic validation messages
/// onto the field key each message is about, so each shows inline below its
/// own field via `errorText` — the same approach `CheckoutScreen` uses for
/// `FoodController.addressErrors` via `_addressFieldErrorMessages`.
const Map<String, String> _profileFieldErrorMessages = {
  'firstName': 'Enter your first name.',
  'lastName': 'Enter your last name.',
  'phone': 'Enter a valid phone number.',
};

Map<String, String> _profileFieldErrors(List<String> errors) {
  return {
    for (final entry in _profileFieldErrorMessages.entries)
      if (errors.contains(entry.value)) entry.key: entry.value,
  };
}

/// Lets the signed-in customer edit their own first name, last name, and
/// phone number, and save them to `profiles` via
/// [ProfileEditController]/[ProfileRepository.updateProfile] (issue #13).
///
/// Avatar editing is intentionally out of scope: there is no existing
/// Supabase Storage plumbing in this codebase to reuse, and building new
/// upload infrastructure was judged out of proportion for this issue.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, this.profileRepository});

  final ProfileRepository? profileRepository;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final ProfileRepository _repository =
      widget.profileRepository ??
      SupabaseProfileRepository(client: Supabase.instance.client);
  late final ProfileEditController _controller = ProfileEditController(
    profileRepository: _repository,
  );

  late Future<CustomerProfile?> _profileFuture;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _fieldsSeeded = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<CustomerProfile?> _loadProfile() async {
    try {
      return await _repository.fetchCurrentProfile();
    } on Object catch (error, stack) {
      ErrorReporting.instance.reportError(
        error,
        stack,
        context: 'EditProfileScreen._loadProfile',
      );
      return null;
    }
  }

  void _seedControllers(CustomerProfile? profile) {
    if (_fieldsSeeded || profile == null) return;
    _fieldsSeeded = true;
    _firstNameController.text = profile.firstName;
    _lastNameController.text = profile.lastName;
    _phoneController.text = profile.phone;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final result = await _controller.submit(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      phone: _phoneController.text,
    );
    if (!mounted) return;
    if (result.isSuccess) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
      // Guarded like `LoginScreen`/`RegisterScreen`'s own back navigation —
      // this screen is always pushed from `ProfileScreen`, but a guard
      // avoids a crash if it were ever reached as a standalone/deep-link
      // route with nothing to pop back to.
      if (context.canPop()) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => AppScaffold(
        title: 'Edit Profile',
        showBackButton: true,
        body: FutureBuilder<CustomerProfile?>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            _seedControllers(snapshot.data);
            final fieldErrors = _profileFieldErrors(_controller.fieldErrors);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(TwSpacing.x5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('Personal details', fontSize: 18),
                        const SizedBox(height: TwSpacing.x4),
                        TextField(
                          key: const ValueKey('profile-first-name'),
                          controller: _firstNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'First name',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: _fieldBorder,
                            errorText: fieldErrors['firstName'],
                          ),
                        ),
                        const SizedBox(height: TwSpacing.x3),
                        TextField(
                          key: const ValueKey('profile-last-name'),
                          controller: _lastNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Last name',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: _fieldBorder,
                            errorText: fieldErrors['lastName'],
                          ),
                        ),
                        const SizedBox(height: TwSpacing.x3),
                        TextField(
                          key: const ValueKey('profile-phone'),
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Phone number',
                            hintText: '+252 …',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            border: _fieldBorder,
                            errorText: fieldErrors['phone'],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: TwSpacing.x8),
                  if (_controller.submissionError case final error?) ...[
                    Text(
                      error,
                      style: TwText.textSm.copyWith(color: TwColors.error),
                    ),
                    const SizedBox(height: TwSpacing.x3),
                  ],
                  GradientActionButton(
                    label: _controller.isSubmitting
                        ? 'Saving...'
                        : 'Save changes',
                    onPressed: _controller.isSubmitting ? null : _save,
                  ),
                  const SizedBox(height: TwSpacing.x8),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
