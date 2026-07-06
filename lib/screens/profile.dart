import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/app_router.dart';
import '../config/theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/app_scaffold.dart';

// class ProfileScreenFull extends StatelessWidget {
//   const ProfileScreenFull({super.key});

//   static const List<_ProfileOption> _options = [
//     _ProfileOption(
//       title: 'My Orders',
//       icon: Icons.shopping_bag,
//       route: AppRoutes.orders,
//     ),
//     _ProfileOption(
//       title: 'Addresses',
//       icon: Icons.location_on,
//       route: AppRoutes.addresses,
//     ),
//     _ProfileOption(
//       title: 'Payment Methods',
//       icon: Icons.payment,
//       route: AppRoutes.paymentMethods,
//     ),
//     _ProfileOption(
//       title: 'Help & Support',
//       icon: Icons.help,
//       route: AppRoutes.support,
//     ),
//     _ProfileOption(
//       title: 'Settings',
//       icon: Icons.settings,
//       route: AppRoutes.settings,
//     ),
//     _ProfileOption(title: 'Logout', icon: Icons.logout),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return AppScaffold(
//       title: 'Profile',
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(TwSpacing.x5),
//         child: Column(
//           children: [
//             Container(
//               width: 100,
//               height: 100,
//               decoration: const BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: TwColors.primaryAccent,
//               ),
//               child: const Icon(Icons.person, size: 50),
//             ),
//             const SizedBox(height: TwSpacing.x5),
//             Text('Amara Johnson', style: TwText.text2xl()),
//             const SizedBox(height: TwSpacing.x2),
//             Text(
//               'amara@example.com',
//               style: TwText.textSm(),
//             ),
//             const SizedBox(height: TwSpacing.x8),
//             OutlinedCard(
//               backgroundColor: Colors.white,
//               borderRadius: 16,
//               child: Column(
//                 children: [
//                   for (final option in _options) ...[
//                     _ProfileOptionTile(option: option),
//                     if (option != _options.last) const Divider(),
//                   ],
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _ProfileOptionTile extends StatelessWidget {
//   const _ProfileOptionTile({required this.option});

//   final _ProfileOption option;

//   @override
//   Widget build(BuildContext context) {
//     return ListTile(
//       contentPadding: EdgeInsets.zero,
//       leading: Icon(option.icon, color: TwColors.primary),
//       title: Text(option.title, style: TwText.fontBoldBase()),
//       trailing: const Icon(Icons.arrow_forward_ios, size: 16),
//       onTap: option.route == null ? null : () => context.push(option.route!),
//     );
//   }
// }

// class _ProfileOption {
//   const _ProfileOption({
//     required this.title,
//     required this.icon,
//     this.route,
//   });

//   final String title;
//   final IconData icon;
//   final String? route;
// }

class ProfileScreenFull extends StatelessWidget {
  const ProfileScreenFull({super.key});

  static const List<_ProfileStat> _orderStats = [
    _ProfileStat(
      icon: Icons.shopping_bag_outlined,
      title: 'My Orders',
      count: '12',
      route: AppRoutes.orders,
    ),
    _ProfileStat(
      icon: Icons.local_shipping_outlined,
      title: 'To Ship',
      count: '3',
      route: AppRoutes.orders,
    ),
    _ProfileStat(
      icon: Icons.inventory_2_outlined,
      title: 'Delivered',
      count: '9',
      route: AppRoutes.orders,
    ),
    _ProfileStat(
      icon: Icons.refresh,
      title: 'Returns',
      count: '2',
      route: AppRoutes.orders,
    ),
  ];

  static const List<_ProfileOption> _accountOptions = [
    _ProfileOption(
      title: 'Addresses',
      icon: Icons.location_on_outlined,
      route: AppRoutes.addresses,
    ),
    _ProfileOption(
      title: 'Payment Methods',
      icon: Icons.payment,
      route: AppRoutes.paymentMethods,
    ),
    _ProfileOption(
      title: 'Wallet',
      icon: Icons.account_balance_wallet_outlined,
      route: AppRoutes.wallet,
      trailingText: '\$120.50',
    ),
    _ProfileOption(title: 'Coupons & Offers', icon: Icons.local_offer_outlined),
    _ProfileOption(title: 'Notifications', icon: Icons.notifications_none),
    _ProfileOption(
      title: 'Help & Support',
      icon: Icons.help_outline,
      route: AppRoutes.support,
    ),
    _ProfileOption(
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
            Row(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: TwColors.primary,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 55,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: TwSpacing.x5),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Amara Johnson', style: TwText.text2xl()),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified,
                          color: Colors.orangeAccent,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('amara@example.com', style: TwText.textSm()),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: TwColors.primary.withOpacityValue(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.workspace_premium,
                            color: TwColors.primary,
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Gold Member',
                            style: TextStyle(
                              color: TwColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: TwSpacing.x8),

            OutlinedCard(
              backgroundColor: Colors.white,
              borderRadius: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Orders', style: TwText.fontBoldBase()),
                  const SizedBox(height: TwSpacing.x5),
                  Row(
                    children: [
                      for (final stat in _orderStats)
                        Expanded(child: _OrderItem(stat: stat)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: TwSpacing.x5),

            OutlinedCard(
              backgroundColor: Colors.white,
              borderRadius: 18,
              child: Column(
                children: [
                  for (final option in _accountOptions) ...[
                    _ProfileOptionTile(option: option),
                    if (option != _accountOptions.last) const Divider(),
                  ],
                ],
              ),
            ),

            const SizedBox(height: TwSpacing.x5),

            OutlinedCard(
              backgroundColor: Colors.white,
              borderRadius: 18,
              child: const _ProfileOptionTile(
                option: _ProfileOption(
                  title: 'Logout',
                  icon: Icons.logout,
                  isLogout: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderItem extends StatelessWidget {
  const _OrderItem({required this.stat});

  final _ProfileStat stat;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: stat.route == null ? null : () => context.push(stat.route!),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: TwSpacing.x1),
        child: Column(
          children: [
            Icon(stat.icon, color: TwColors.primary, size: 30),
            const SizedBox(height: 10),
            Text(
              stat.title,
              style: TwText.fontBoldBase(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(stat.count, style: TwText.textSm()),
          ],
        ),
      ),
    );
  }
}

class _ProfileOptionTile extends StatelessWidget {
  const _ProfileOptionTile({required this.option});

  final _ProfileOption option;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(option.icon, color: TwColors.primary),
      title: Text(
        option.title,
        style: TwText.fontBoldBase().copyWith(
          color: option.isLogout ? TwColors.primary : null,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (option.trailingText != null)
            Text(option.trailingText!, style: TwText.textSm()),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios, size: 16),
        ],
      ),
      onTap: option.route == null ? null : () => context.push(option.route!),
    );
  }
}

class _ProfileOption {
  const _ProfileOption({
    required this.title,
    required this.icon,
    this.route,
    this.trailingText,
    this.isLogout = false,
  });

  final String title;
  final IconData icon;
  final String? route;
  final String? trailingText;
  final bool isLogout;
}

class _ProfileStat {
  const _ProfileStat({
    required this.icon,
    required this.title,
    required this.count,
    this.route,
  });

  final IconData icon;
  final String title;
  final String count;
  final String? route;
}
