import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
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
    } on Object {
      return null;
    }
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

  static const List<ProfileOption> _accountOptions = [
    ProfileOption(
      title: 'Addresses',
      icon: Icons.location_on_outlined,
      route: AppRoutes.addresses,
    ),
    ProfileOption(
      title: 'Payment Methods',
      icon: Icons.payment,
      route: AppRoutes.paymentMethods,
    ),
    ProfileOption(
      title: 'Wallet',
      icon: Icons.account_balance_wallet_outlined,
      route: AppRoutes.wallet,
      trailingText: '\$120.50',
    ),
    ProfileOption(
      title: 'Rewards & Achievements',
      icon: Icons.emoji_events_outlined,
      route: AppRoutes.rewards,
    ),
    ProfileOption(title: 'Coupons & Offers', icon: Icons.local_offer_outlined),
    ProfileOption(title: 'Notifications', icon: Icons.notifications_none),
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
            const ProfileOptionsCard(options: _accountOptions),
            const SizedBox(height: TwSpacing.x4),
            LogoutCard(onTap: () => _logout(context)),
          ],
        ),
      ),
    );
  }
}
