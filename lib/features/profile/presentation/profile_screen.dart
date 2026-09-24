import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../platform/error_reporting/error_reporter.dart';
import '../../../platform/localization/app_money.dart';
import '../../../widgets/app_scaffold.dart';
import '../../auth/data/auth_error_message.dart';
import '../../auth/data/auth_service.dart';
import '../../wallet/data/wallet_repository.dart';
import '../data/profile_repository.dart';
import '../models/customer_profile.dart';
import 'models/profile_models.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_options_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.profileRepository,
    this.walletRepository,
  });

  final ProfileRepository? profileRepository;

  /// The same [WalletRepository] the real wallet screen reads from, so the
  /// wallet balance shown here can never drift into a second, independently
  /// hardcoded number (see issue #14).
  final WalletRepository? walletRepository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<CustomerProfile?> _profileFuture;
  late Future<int?> _walletBalanceFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
    _walletBalanceFuture = _loadWalletBalance();
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

  /// Reads the wallet balance from the exact same [WalletRepository] the
  /// wallet screen uses (`wallet_transactions`), rather than a second,
  /// independently hardcoded figure — see issue #14. Returns `null` on
  /// failure so the row simply omits the trailing amount instead of ever
  /// showing a stale or fabricated number.
  Future<int?> _loadWalletBalance() async {
    try {
      final repository =
          widget.walletRepository ??
          SupabaseWalletRepository(client: Supabase.instance.client);
      return await repository.fetchBalance();
    } on Object catch (error, stack) {
      ErrorReporting.instance.reportError(
        error,
        stack,
        context: 'ProfileScreen._loadWalletBalance',
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

  // Not `const`/static: the Wallet row's trailing amount depends on the
  // loaded balance (see `_walletBalanceFuture`), so this list is rebuilt per
  // frame from whatever the wallet balance future currently holds.
  //
  // 'Coupons & Offers' was removed rather than wired up: there is no coupons
  // feature anywhere in the app to link to (issue #14).
  //
  // 'Notifications' now points at the Settings screen, which owns the real
  // notification toggles, instead of resolving to no route at all.
  List<ProfileOption> _accountOptions({String? walletBalanceText}) => [
    const ProfileOption(
      title: 'Addresses',
      icon: Icons.location_on_outlined,
      route: AppRoutes.addresses,
    ),
    ProfileOption(
      title: 'Wallet',
      icon: Icons.account_balance_wallet_outlined,
      route: AppRoutes.wallet,
      trailingText: walletBalanceText,
    ),
    const ProfileOption(
      title: 'Notifications',
      icon: Icons.notifications_none,
      route: AppRoutes.settings,
    ),
    const ProfileOption(
      title: 'Help & Support',
      icon: Icons.help_outline,
      route: AppRoutes.support,
    ),
    const ProfileOption(
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
        padding: const EdgeInsets.all(TwSpacing.x5),
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
            const SizedBox(height: TwSpacing.x5),
            Text('Account', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: TwSpacing.x3),
            FutureBuilder<int?>(
              future: _walletBalanceFuture,
              builder: (context, walletSnapshot) {
                final balance = walletSnapshot.data;
                return ProfileOptionsCard(
                  options: _accountOptions(
                    walletBalanceText: balance == null
                        ? null
                        : AppMoney.formatCents(balance),
                  ),
                  onOptionTap: _handleOptionTap,
                );
              },
            ),
            const SizedBox(height: TwSpacing.x4),
            LogoutCard(onTap: () => _logout(context)),
          ],
        ),
      ),
    );
  }
}
