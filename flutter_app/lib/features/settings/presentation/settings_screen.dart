import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../config/theme.dart';
import '../../../platform/notifications/push_notifications.dart';
import '../../../widgets/app_scaffold.dart';
import '../../auth/data/auth_error_message.dart';
import '../../auth/data/auth_service.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/models/customer_profile.dart';
import '../../profile/presentation/profile_edit_controller.dart';
import '../data/notification_preferences_repository.dart';
import 'widgets/about_zivo_sheet.dart';
import 'widgets/account_danger_zone.dart';
import 'widgets/account_section.dart';
import 'widgets/email_edit_sheet.dart';
import 'widgets/name_edit_sheet.dart';
import 'widgets/notifications_section.dart';
import 'widgets/phone_edit_sheet.dart';
import 'widgets/preferences_section.dart';
import 'widgets/support_section.dart';

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
  /// Shared shape for every modal bottom sheet this screen opens (the
  /// profile-edit sheets and the About sheet) — pulled out once instead of
  /// repeated at each call site.
  static const _sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(TwRadius.hero)),
  );

  NotificationPreferences _preferences = NotificationPreferences.defaults;
  CustomerProfile? _profile;
  bool _profileLoading = true;
  String? _email;

  // Assigned eagerly in didChangeDependencies (not via a lazy `late final`
  // initializer, and not in initState -- AppScope.of(context) uses
  // dependOnInheritedWidgetOfExactType, which Flutter forbids calling from
  // initState) so it's only ever resolved once, while context is active.
  // A lazy initializer would otherwise run on first access, which could be
  // as late as dispose() if no sheet was ever opened, crashing with
  // "Looking up a deactivated widget's ancestor is unsafe."
  late final ProfileEditController _profileEditController;
  bool _dependenciesInitialized = false;

  // Both getters below resolve the real Supabase-backed default from
  // AppScope (issue #284) instead of reaching for `Supabase.instance.client`
  // or `AuthService()` directly -- only evaluated when the widget's own
  // override is absent (production; every test injects both).
  AuthService get _authService =>
      widget.authService ??
      AuthService(client: AppScope.of(context).supabaseClient);

  ProfileRepository get _profileRepository =>
      widget.profileRepository ??
      SupabaseProfileRepository(client: AppScope.of(context).supabaseClient);

  NotificationPreferencesStorage get _preferencesStorage =>
      widget.notificationPreferencesStorage ??
      SharedPreferencesNotificationPreferencesStorage();

  PushNotificationGateway get _pushNotificationGateway =>
      widget.pushNotificationGateway ?? PushNotifications.instance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesInitialized) return;
    _dependenciesInitialized = true;
    _profileEditController = ProfileEditController(
      profileRepository: _profileRepository,
      authService: _authService,
    );
    _email = _readCurrentUserEmail();
    _loadProfile();
    _loadPreferences();
  }

  @override
  void dispose() {
    _profileEditController.dispose();
    super.dispose();
  }

  // _authService's default construction reaches for AppScope.of(context),
  // which asserts if this screen is rendered with no AppScope ancestor (e.g.
  // a widget test that renders this screen without an injected authService
  // and without wrapping it in AppScope). Guard every read the same way
  // _loadProfile already guards the profile repository, so a screen shown
  // without that setup still renders instead of crashing.
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
  /// the edit sheet only pops itself with a result on success.
  void _applyProfileEditResult(ProfileEditResult? result) {
    if (!mounted || result == null || !result.isSuccess) return;
    setState(() {
      if (result.profile != null) _profile = result.profile;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile updated')));
  }

  /// Opens [builder] as a modal profile-edit bottom sheet using this
  /// screen's shared [_sheetShape]. Factored out because [_editName],
  /// [_editPhone], and [_editEmail] otherwise repeat the same
  /// `showModalBottomSheet` call shape with only the sheet widget differing.
  Future<ProfileEditResult?> _showProfileEditSheet(WidgetBuilder builder) {
    return showModalBottomSheet<ProfileEditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: _sheetShape,
      builder: builder,
    );
  }

  Future<void> _editName() async {
    final result = await _showProfileEditSheet(
      (sheetContext) =>
          NameEditSheet(profile: _profile, controller: _profileEditController),
    );
    _applyProfileEditResult(result);
  }

  Future<void> _editPhone() async {
    final result = await _showProfileEditSheet(
      (sheetContext) =>
          PhoneEditSheet(profile: _profile, controller: _profileEditController),
    );
    _applyProfileEditResult(result);
  }

  Future<void> _editEmail() async {
    final result = await _showProfileEditSheet(
      (sheetContext) =>
          EmailEditSheet(email: _email, controller: _profileEditController),
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
      shape: _sheetShape,
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
            NotificationsSection(
              preferences: _preferences,
              onPushNotificationsChanged: _setPushNotifications,
              onEmailNotificationsChanged: (value) => _updatePreferences(
                _preferences.copyWith(emailNotifications: value),
              ),
              onPromotionalEmailsChanged: (value) => _updatePreferences(
                _preferences.copyWith(promotionalEmails: value),
              ),
              onOrderUpdatesChanged: (value) => _updatePreferences(
                _preferences.copyWith(orderUpdates: value),
              ),
            ),
            const SizedBox(height: TwSpacing.sectionGap),
            AccountSection(
              nameSubtitle: _profileLoading
                  ? 'Loading…'
                  : _nameSubtitle(_profile),
              phoneSubtitle: _profileLoading
                  ? 'Loading…'
                  : ((_profile?.phone.isNotEmpty ?? false)
                        ? _profile!.phone
                        : 'Not added yet'),
              dobSubtitle: _profileLoading
                  ? 'Loading…'
                  : _dobSubtitle(_profile?.dob),
              emailSubtitle: (_email?.isNotEmpty ?? false)
                  ? _email!
                  : 'Not available',
              onEditName: _editName,
              onEditPhone: _editPhone,
              onEditDob: _editDob,
              onEditEmail: _editEmail,
            ),
            const SizedBox(height: TwSpacing.sectionGap),
            const PreferencesSection(),
            const SizedBox(height: TwSpacing.sectionGap),
            SupportSection(onAboutUsTap: _showAboutSheet),
            const SizedBox(height: TwSpacing.sectionGap),
            AccountDangerZone(
              onLogoutTap: _logout,
              onDeleteAccountTap: _confirmDeleteAccount,
            ),
            const SizedBox(height: TwSpacing.x6),
          ],
        ),
      ),
    );
  }
}
