import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../widgets/app_scaffold.dart';
import '../../auth/data/auth_service.dart';
import 'models/profile_models.dart';
import 'widgets/order_stats_card.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_options_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    try {
      await AuthService().signOut();
      if (context.mounted) context.go(AppRoutes.login);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not log out: $error')));
    }
  }

  static const List<ProfileStat> _orderStats = [
    ProfileStat(
      icon: Icons.shopping_bag_outlined,
      title: 'My Orders',
      count: '12',
      route: AppRoutes.orders,
    ),
    ProfileStat(
      icon: Icons.local_shipping_outlined,
      title: 'To Ship',
      count: '3',
      route: AppRoutes.orders,
    ),
    ProfileStat(
      icon: Icons.inventory_2_outlined,
      title: 'Delivered',
      count: '9',
      route: AppRoutes.orders,
    ),
    ProfileStat(
      icon: Icons.refresh,
      title: 'Returns',
      count: '2',
      route: AppRoutes.orders,
    ),
  ];

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
            const ProfileHeader(),
            const SizedBox(height: TwSpacing.x8),
            const OrderStatsCard(stats: _orderStats),
            const SizedBox(height: TwSpacing.x5),
            const ProfileOptionsCard(options: _accountOptions),
            const SizedBox(height: TwSpacing.x5),
            LogoutCard(onTap: () => _logout(context)),
          ],
        ),
      ),
    );
  }
}
