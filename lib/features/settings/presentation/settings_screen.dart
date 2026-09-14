import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_scaffold.dart';
import '../../auth/data/auth_error_message.dart';
import '../../auth/data/auth_service.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/models/customer_profile.dart';
import '../data/notification_preferences_repository.dart';
import 'widgets/about_zivo_sheet.dart';
import 'widgets/setting_card.dart';
import 'widgets/toggle_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.authService,
    this.profileRepository,
    this.notificationPreferencesStorage,
  });

  final AuthService? authService;
  final ProfileRepository? profileRepository;
  final NotificationPreferencesStorage? notificationPreferencesStorage;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  NotificationPreferences _preferences = NotificationPreferences.defaults;
  late final Future<CustomerProfile?> _profileFuture;
  String? _email;

  AuthService get _authService => widget.authService ?? AuthService();

  ProfileRepository get _profileRepository =>
      widget.profileRepository ??
      SupabaseProfileRepository(client: Supabase.instance.client);

  NotificationPreferencesStorage get _preferencesStorage =>
      widget.notificationPreferencesStorage ??
      SharedPreferencesNotificationPreferencesStorage();

  @override
  void initState() {
    super.initState();
    _email = _readCurrentUserEmail();
    _profileFuture = _loadProfile();
    _loadPreferences();
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

  Future<CustomerProfile?> _loadProfile() async {
    try {
      return await _profileRepository.fetchCurrentProfile();
    } on Object {
      return null;
    }
  }

  Future<void> _loadPreferences() async {
    final ownerId = _readCurrentUserId();
    if (ownerId == null) return;
    final stored = await _preferencesStorage.read(ownerId);
    if (!mounted) return;
    setState(() => _preferences = stored);
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
      // The account's PII is now wiped server-side; sign out immediately so
      // the local session can't keep operating against the emptied profile
      // (see ProfileRepository.deleteAccount's doc comment).
      await _authService.signOut();
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
            const SectionTitle('Notifications', fontSize: 18),
            const SizedBox(height: TwSpacing.rhythmDefault),
            OutlinedCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ToggleCard(
                    title: 'Push Notifications',
                    subtitle: 'Get notifications about your orders',
                    value: _preferences.pushNotifications,
                    onChanged: (value) => _updatePreferences(
                      _preferences.copyWith(pushNotifications: value),
                    ),
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
            const SizedBox(height: TwSpacing.rhythmSection),
            const SectionTitle('Account', fontSize: 18),
            const SizedBox(height: TwSpacing.rhythmDefault),
            OutlinedCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // Shows the real signed-in email instead of the old
                  // hardcoded placeholder. Stays inert (no chevron/onTap):
                  // the profile-edit flow added by issue #13 only edits
                  // name/phone, not the auth email, so there is nowhere
                  // honest to send this tap yet.
                  SettingCard(
                    title: 'Email Address',
                    subtitle: (_email?.isNotEmpty ?? false)
                        ? _email!
                        : 'Not available',
                    icon: Icons.email_outlined,
                  ),
                  const Divider(height: 1),
                  FutureBuilder<CustomerProfile?>(
                    future: _profileFuture,
                    builder: (context, snapshot) {
                      final phone = snapshot.data?.phone;
                      final isLoading =
                          snapshot.connectionState == ConnectionState.waiting;
                      final subtitle = isLoading
                          ? 'Loading…'
                          : ((phone?.isNotEmpty ?? false)
                                ? phone!
                                : 'Not added yet');
                      return SettingCard(
                        title: 'Phone Number',
                        subtitle: subtitle,
                        icon: Icons.phone_outlined,
                        // A real profile-edit flow now exists on master
                        // (issue #13) and lets the signed-in user change
                        // their phone number, so this row can honestly
                        // navigate there instead of staying inert.
                        onTap: () => context.push(AppRoutes.editProfile),
                      );
                    },
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
            const SizedBox(height: TwSpacing.rhythmSection),
            const SectionTitle('Preferences', fontSize: 18),
            const SizedBox(height: TwSpacing.rhythmDefault),
            OutlinedCard(
              padding: EdgeInsets.zero,
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
            const SizedBox(height: TwSpacing.rhythmSection),
            const SectionTitle('Support', fontSize: 18),
            const SizedBox(height: TwSpacing.rhythmDefault),
            OutlinedCard(
              padding: EdgeInsets.zero,
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
            const SizedBox(height: TwSpacing.rhythmSection),
            PrimaryButton(
              label: 'Logout',
              onPressed: _logout,
              color: TwColors.error,
            ),
            const SizedBox(height: TwSpacing.rhythmDefault),
            Center(
              child: TextButton(
                onPressed: _confirmDeleteAccount,
                child: const Text(
                  'Delete Account',
                  style: TextStyle(color: TwColors.error),
                ),
              ),
            ),
            const SizedBox(height: TwSpacing.x5),
          ],
        ),
      ),
    );
  }
}
