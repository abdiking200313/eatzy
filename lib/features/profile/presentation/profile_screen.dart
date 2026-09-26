import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../platform/error_reporting/error_reporter.dart';
import '../../../widgets/app_scaffold.dart';
import '../../auth/data/auth_error_message.dart';
import '../../auth/data/auth_service.dart';
import '../data/profile_repository.dart';
import '../models/customer_profile.dart';
import 'models/profile_models.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_options_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.profileRepository});

  final ProfileRepository? profileRepository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<CustomerProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<CustomerProfile?> _loadProfile() async {
    try {
      final repository =
          widget.profileRepository ??
          SupabaseProfileRepository(client: Supabase.instance.client);
      return await repository.fetchCurrentProfile();
    } on Object catch (error, stack) {
      // Falls back to the "Zivo customer" empty state below either way (see
      // ProfileHeader usage in build()), but the failure must not be
      // silently swallowed — see issue #40.
      ErrorReporting.instance.reportError(
        error,
        stack,
        context: 'ProfileScreen._loadProfile',
      );
      return null;
    }
  }

  /// Reloads the profile after returning from a pushed [ProfileOption]
  /// route (rather than threading a result value back through `pop`), the
  /// same way the removed `EditProfileScreen`'s `_editProfile` always did.
  /// Profile editing now lives in Settings (Name/Phone/Date of
  /// Birth/Email sheets), so only a trip through Settings can have changed
  /// what the header above shows.
  Future<void> _handleOptionTap(
    BuildContext context,
    ProfileOption option,
  ) async {
    final route = option.route;
    if (route == null) return;
    await context.push(route);
    if (!context.mounted || route != AppRoutes.settings) return;
    setState(() {
      _profileFuture = _loadProfile();
    });
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await AuthService().signOut();
      if (context.mounted) context.go(AppRoutes.login);
    } catch (error) {
      if (!context.mounted) return;
      final message = describeAuthError(error, context: 'Logout');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not log out: $message')));
    }
  }

  // 'Coupons & Offers' was removed rather than wired up: there is no coupons
  // feature anywhere in the app to link to (issue #14). Addresses and Wallet
  // are hidden while delivery addresses and payments are out of scope
  // (owner decision, 2026-09-25).
  //
  // 'Notifications' points at the Settings screen, which owns the real
  // notification toggles.
  static const _accountOptions = [
    ProfileOption(
      title: 'Notifications',
      icon: Icons.notifications_none,
      route: AppRoutes.settings,
    ),
    ProfileOption(
      title: 'Help & Support',
      icon: Icons.help_outline,
      route: AppRoutes.support,
    ),
    ProfileOption(
      title: 'Settings',
      icon: Icons.settings_outlined,
      route: AppRoutes.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Profile',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          TwSpacing.x5,
          TwSpacing.x5,
          TwSpacing.x5,
          TwSpacing.x6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<CustomerProfile?>(
              future: _profileFuture,
              builder: (context, snapshot) {
                final profile = snapshot.data;
                return ProfileHeader(
                  displayName: profile?.displayName ?? 'Zivo customer',
                  contactLabel: profile?.phone.isNotEmpty == true
                      ? profile!.phone
                      : 'Somalia • USD',
                  isLoading:
                      snapshot.connectionState == ConnectionState.waiting,
                );
              },
            ),
            const SizedBox(height: TwSpacing.sectionGap),
            const Text('Account', style: TwText.sectionTitle),
            const SizedBox(height: TwSpacing.headerToContent),
            ProfileOptionsCard(
              options: _accountOptions,
              onOptionTap: _handleOptionTap,
            ),
            const SizedBox(height: TwSpacing.x4),
            LogoutCard(onTap: () => _logout(context)),
          ],
        ),
      ),
    );
  }
}
