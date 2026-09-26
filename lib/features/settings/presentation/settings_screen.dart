import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../platform/notifications/push_notifications.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_scaffold.dart';
import '../../auth/data/auth_error_message.dart';
import '../../auth/data/auth_service.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/models/customer_profile.dart';
import '../../profile/presentation/profile_edit_controller.dart';
import '../data/notification_preferences_repository.dart';
import 'widgets/about_zivo_sheet.dart';
import 'widgets/edit_field_sheet.dart';
import 'widgets/setting_card.dart';
import 'widgets/toggle_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.authService,
    this.profileRepository,
    this.notificationPreferencesStorage,
    this.pushNotificationGateway,
  });

  final AuthService? authService;
  final ProfileRepository? profileRepository;
  final NotificationPreferencesStorage? notificationPreferencesStorage;

  /// Overridable for tests; defaults to [PushNotifications.instance] (issue
  /// #47).
  final PushNotificationGateway? pushNotificationGateway;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  NotificationPreferences _preferences = NotificationPreferences.defaults;
  CustomerProfile? _profile;
  bool _profileLoading = true;
  String? _email;

  late final ProfileEditController _profileEditController =
      ProfileEditController(
        profileRepository: widget.profileRepository,
        authService: widget.authService,
      );

  AuthService get _authService => widget.authService ?? AuthService();

  ProfileRepository get _profileRepository =>
      widget.profileRepository ??
      SupabaseProfileRepository(client: Supabase.instance.client);

  NotificationPreferencesStorage get _preferencesStorage =>
      widget.notificationPreferencesStorage ??
      SharedPreferencesNotificationPreferencesStorage();

  PushNotificationGateway get _pushNotificationGateway =>
      widget.pushNotificationGateway ?? PushNotifications.instance;

  @override
  void initState() {
    super.initState();
    _email = _readCurrentUserEmail();
    _loadProfile();
    _loadPreferences();
  }

  @override
  void dispose() {
    _profileEditController.dispose();
    super.dispose();
  }

  // AuthService()'s default constructor reaches for Supabase.instance.client,
  // which throws if Supabase was never initialized (e.g. a widget test that
  // renders this screen without an injected authService). Guard every read
  // the same way _loadProfile already guards the profile repository, so a
  // screen shown without Supabase set up still renders instead of crashing.
  String? _readCurrentUserEmail() {
    try {
      return _authService.getCurrentUserEmail();
    } on Object {
      return null;
    }
  }

  String? _readCurrentUserId() {
    try {
      return _authService.getCurrentUserId();
    } on Object {
      return null;
    }
  }

  Future<void> _loadProfile() async {
    CustomerProfile? profile;
    try {
      profile = await _profileRepository.fetchCurrentProfile();
    } on Object {
      profile = null;
    }
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _profileLoading = false;
    });
  }

  /// Applies a successful [ProfileEditResult] from one of the Name / Phone
  /// Number / Date of Birth sheets: updates the displayed profile in place
  /// and shows the standard confirmation `SnackBar`. A `null`/unsuccessful
  /// result (sheet dismissed without saving, or save failed) is a no-op —
  /// [EditFieldSheet] only pops itself with a result on success.
  void _applyProfileEditResult(ProfileEditResult? result) {
    if (!mounted || result == null || !result.isSuccess) return;
    setState(() {
      if (result.profile != null) _profile = result.profile;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile updated')));
  }

  Future<void> _editName() async {
    final result = await showModalBottomSheet<ProfileEditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TwRadius.hero),
        ),
      ),
      builder: (sheetContext) => EditFieldSheet(
        title: 'Edit name',
        controller: _profileEditController,
        fields: [
          EditFieldSpec(
            initialValue: _profile?.firstName ?? '',
            label: 'First name',
            textCapitalization: TextCapitalization.words,
            prefixIcon: Icons.person_outline,
            errorMessages: const ['Enter your first name.'],
          ),
          EditFieldSpec(
            initialValue: _profile?.lastName ?? '',
            label: 'Last name',
            textCapitalization: TextCapitalization.words,
            prefixIcon: Icons.person_outline,
            errorMessages: const ['Enter your last name.'],
          ),
        ],
        onSave: (values) => _profileEditController.updateName(
          firstName: values[0],
          lastName: values[1],
        ),
      ),
    );
    _applyProfileEditResult(result);
  }

  Future<void> _editPhone() async {
    final result = await showModalBottomSheet<ProfileEditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TwRadius.hero),
        ),
      ),
      builder: (sheetContext) => EditFieldSheet(
        title: 'Edit phone number',
        controller: _profileEditController,
        fields: [
          EditFieldSpec(
            initialValue: _profile?.phone ?? '',
            label: 'Phone number',
            hintText: '+252 …',
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_outlined,
            errorMessages: const [
              'Enter your phone number.',
              'Please enter a valid phone number.',
            ],
          ),
        ],
        onSave: (values) => _profileEditController.updatePhone(values[0]),
      ),
    );
    _applyProfileEditResult(result);
  }

  Future<void> _editEmail() async {
    final result = await showModalBottomSheet<ProfileEditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TwRadius.hero),
        ),
      ),
      builder: (sheetContext) => EditFieldSheet(
        title: 'Edit email address',
        controller: _profileEditController,
        helperText:
            "We'll send a confirmation link to your new email address. "
            "The change only applies once you confirm it.",
        fields: [
          EditFieldSpec(
            initialValue: _email ?? '',
            label: 'Email address',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
            errorMessages: const [
              'Enter your email address.',
              'Please enter a valid email address.',
              "That's already your email address.",
            ],
          ),
        ],
        onSave: (values) => _profileEditController.updateEmail(values[0]),
      ),
    );
    if (!mounted || result == null || !result.isSuccess) return;
    // updateEmail's contract leaves `profile` null on success -- the change
    // only takes effect once the user confirms via the emailed link, so
    // there is nothing yet to merge into `_profile`/`_email`.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Check your new inbox to confirm your email change.'),
      ),
    );
  }

  Future<void> _editDob() async {
    final now = DateTime.now();
    final eighteenYearsAgo = DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 120, now.month, now.day),
      lastDate: now,
      initialDate: _profile?.dob ?? eighteenYearsAgo,
    );
    if (picked == null || !mounted) return;
    final result = await _profileEditController.updateDob(picked);
    if (!mounted) return;
    if (result.isSuccess) {
      _applyProfileEditResult(result);
      return;
    }
    final message = result.errors.isNotEmpty
        ? result.errors.first
        : (_profileEditController.submissionError ??
              'Could not save your profile. Please try again.');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// `CustomerProfile.displayName` always falls back to 'Zivo customer'
  /// rather than an empty string, which is right for `ProfileHeader` but
  /// would misleadingly imply a name was saved on this row -- so this row
  /// checks the underlying first/last name directly instead.
  static String _nameSubtitle(CustomerProfile? profile) {
    final hasName =
        (profile?.firstName.isNotEmpty ?? false) ||
        (profile?.lastName.isNotEmpty ?? false);
    return hasName ? profile!.displayName : 'Not added yet';
  }

  static String _dobSubtitle(DateTime? dob) {
    return dob == null
        ? 'Not added yet'
        : DateFormat('MMM d, yyyy').format(dob);
  }

  Future<void> _loadPreferences() async {
    final ownerId = _readCurrentUserId();
    if (ownerId == null) return;
    var stored = await _preferencesStorage.read(ownerId);
    // Reconcile a stale "on" against the real OS permission (issue #47):
    // before this issue, toggling this switch never asked for permission,
    // so an existing install can have `pushNotifications: true` saved with
    // no permission ever granted -- exactly the false promise the issue is
    // about. A device that denied/revoked it since should show (and save)
    // the switch as off rather than keep claiming push is on.
    if (stored.pushNotifications) {
      final hasPermission = await _readHasPushPermission();
      if (!hasPermission) {
        stored = stored.copyWith(pushNotifications: false);
        await _preferencesStorage.write(ownerId, stored);
      }
    }
    if (!mounted) return;
    setState(() => _preferences = stored);
  }

  /// Wraps [PushNotificationGateway.hasPermission], treating a failure (no
  /// Firebase platform channel, as in a plain widget test that doesn't
  /// inject a fake gateway) as "can't tell" rather than forcing the
  /// preference off.
  Future<bool> _readHasPushPermission() async {
    try {
      return await _pushNotificationGateway.hasPermission();
    } on Object {
      return true;
    }
  }

  Future<void> _updatePreferences(NotificationPreferences next) async {
    // Apply immediately so the switch feels responsive; the write below is
    // fire-and-forget local persistence, not something the toggle should
    // block on.
    setState(() => _preferences = next);
    final ownerId = _readCurrentUserId();
    if (ownerId == null) return;
    await _preferencesStorage.write(ownerId, next);
  }

  /// Handles the "Push Notifications" toggle specifically (issue #47):
  /// turning it on must actually request OS permission first, and only
  /// persists "on" if that permission is granted -- otherwise the toggle
  /// stays off and the user is told why, instead of silently lying about
  /// whether push notifications will arrive. Turning it off never needs
  /// permission, so it just persists like any other preference.
  Future<void> _setPushNotifications(bool enabled) async {
    if (!enabled) {
      await _updatePreferences(_preferences.copyWith(pushNotifications: false));
      return;
    }

    final granted = await _pushNotificationGateway.requestPermission();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notifications are blocked for Zivo. Enable them in your '
            'device settings to turn this on.',
          ),
        ),
      );
      return;
    }
    await _updatePreferences(_preferences.copyWith(pushNotifications: true));
  }

  Future<void> _logout() async {
    try {
      await _authService.signOut();
      if (mounted) context.go(AppRoutes.login);
    } catch (error) {
      if (!mounted) return;
      final message = describeAuthError(error, context: 'Logout');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not log out: $message')));
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(TwRadius.hero)),
        ),
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently removes your profile and personal data. '
          "This can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: TwColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    try {
      await _profileRepository.deleteAccount();
      // The server already revoked every session, so a failing sign-out call
      // must not be reported as a failed deletion; still clear locally.
      try {
        await _authService.signOut();
      } on Object {
        // Local session is cleared by signOut even when the server rejects it.
      }
      if (mounted) context.go(AppRoutes.login);
    } catch (error) {
      if (!mounted) return;
      final message = describeAuthError(error, context: 'Account deletion');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete account: $message')),
      );
    }
  }

  void _showAboutSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TwRadius.hero),
        ),
      ),
      builder: (context) => const AboutZivoSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Settings',
      showBackButton: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(TwSpacing.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notifications', style: TwText.sectionTitle),
            const SizedBox(height: TwSpacing.headerToContent),
            OutlinedCard(
              padding: EdgeInsets.zero,
              borderRadius: TwRadius.card,
              child: Column(
                children: [
                  ToggleCard(
                    title: 'Push Notifications',
                    subtitle: 'Get notifications about your orders',
                    value: _preferences.pushNotifications,
                    onChanged: _setPushNotifications,
                  ),
                  const Divider(height: 1),
                  ToggleCard(
                    title: 'Email Notifications',
                    subtitle: 'Receive updates via email',
                    value: _preferences.emailNotifications,
                    onChanged: (value) => _updatePreferences(
                      _preferences.copyWith(emailNotifications: value),
                    ),
                  ),
                  const Divider(height: 1),
                  ToggleCard(
                    title: 'Promotional Emails',
                    subtitle: 'Get exclusive deals and offers',
                    value: _preferences.promotionalEmails,
                    onChanged: (value) => _updatePreferences(
                      _preferences.copyWith(promotionalEmails: value),
                    ),
                  ),
                  const Divider(height: 1),
                  ToggleCard(
                    title: 'Order Updates',
                    subtitle: 'Receive order status updates',
                    value: _preferences.orderUpdates,
                    onChanged: (value) => _updatePreferences(
                      _preferences.copyWith(orderUpdates: value),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: TwSpacing.sectionGap),
            const Text('Account', style: TwText.sectionTitle),
            const SizedBox(height: TwSpacing.headerToContent),
            OutlinedCard(
              padding: EdgeInsets.zero,
              borderRadius: TwRadius.card,
              child: Column(
                children: [
                  SettingCard(
                    title: 'Name',
                    subtitle: _profileLoading
                        ? 'Loading…'
                        : _nameSubtitle(_profile),
                    icon: Icons.person_outline,
                    onTap: _editName,
                  ),
                  const Divider(height: 1),
                  SettingCard(
                    title: 'Phone Number',
                    subtitle: _profileLoading
                        ? 'Loading…'
                        : ((_profile?.phone.isNotEmpty ?? false)
                              ? _profile!.phone
                              : 'Not added yet'),
                    icon: Icons.phone_outlined,
                    onTap: _editPhone,
                  ),
                  const Divider(height: 1),
                  SettingCard(
                    title: 'Date of Birth',
                    subtitle: _profileLoading
                        ? 'Loading…'
                        : _dobSubtitle(_profile?.dob),
                    icon: Icons.cake_outlined,
                    onTap: _editDob,
                  ),
                  const Divider(height: 1),
                  // Now honestly navigable: unlike before issue #13's
                  // Settings migration, an editable email flow exists
                  // (`_editEmail`) so this row no longer has to stay inert.
                  SettingCard(
                    title: 'Email Address',
                    subtitle: (_email?.isNotEmpty ?? false)
                        ? _email!
                        : 'Not available',
                    icon: Icons.email_outlined,
                    onTap: _editEmail,
                  ),
                  const Divider(height: 1),
                  SettingCard(
                    title: 'Change Password',
                    subtitle: 'Update your password',
                    icon: Icons.lock_outlined,
                    onTap: () => context.push(AppRoutes.resetPassword),
                  ),
                ],
              ),
            ),
            const SizedBox(height: TwSpacing.sectionGap),
            const Text('Preferences', style: TwText.sectionTitle),
            const SizedBox(height: TwSpacing.headerToContent),
            OutlinedCard(
              padding: EdgeInsets.zero,
              borderRadius: TwRadius.card,
              child: Column(
                children: [
                  // No language/currency/theme infrastructure exists yet;
                  // these stay non-interactive "coming soon" rows rather
                  // than implying settings that don't do anything (#10).
                  const SettingCard(
                    title: 'Language',
                    subtitle: 'Coming soon',
                    icon: Icons.language_outlined,
                  ),
                  const Divider(height: 1),
                  const SettingCard(
                    title: 'Currency',
                    subtitle: 'Coming soon',
                    icon: Icons.attach_money_outlined,
                  ),
                  const Divider(height: 1),
                  const SettingCard(
                    title: 'Theme',
                    subtitle: 'Coming soon',
                    icon: Icons.brightness_7_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: TwSpacing.sectionGap),
            const Text('Support', style: TwText.sectionTitle),
            const SizedBox(height: TwSpacing.headerToContent),
            OutlinedCard(
              padding: EdgeInsets.zero,
              borderRadius: TwRadius.card,
              child: Column(
                children: [
                  SettingCard(
                    title: 'About Us',
                    subtitle: 'Learn about Zivo',
                    icon: Icons.info_outlined,
                    onTap: _showAboutSheet,
                  ),
                  const Divider(height: 1),
                  // Real in-app Privacy Policy / Terms screens now exist
                  // (issue #37) — see PrivacyPolicyScreen/
                  // TermsOfServiceScreen for the drafted text and their doc
                  // comments for the remaining app-store hosted-URL gap.
                  SettingCard(
                    title: 'Privacy Policy',
                    subtitle: 'How we handle your data',
                    icon: Icons.privacy_tip_outlined,
                    onTap: () => context.push(AppRoutes.privacyPolicy),
                  ),
                  const Divider(height: 1),
                  SettingCard(
                    title: 'Terms & Conditions',
                    subtitle: 'Rules for using Zivo',
                    icon: Icons.description_outlined,
                    onTap: () => context.push(AppRoutes.termsOfService),
                  ),
                ],
              ),
            ),
            const SizedBox(height: TwSpacing.sectionGap),
            PrimaryButton(
              label: 'Logout',
              onPressed: _logout,
              color: TwColors.error,
            ),
            const SizedBox(height: TwSpacing.x3_5),
            Center(
              child: TextButton(
                onPressed: _confirmDeleteAccount,
                child: const Text(
                  'Delete Account',
                  style: TextStyle(color: TwColors.error),
                ),
              ),
            ),
            const SizedBox(height: TwSpacing.x6),
          ],
        ),
      ),
    );
  }
}
