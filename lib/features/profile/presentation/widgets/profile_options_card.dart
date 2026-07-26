import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import '../models/profile_models.dart';

class ProfileOptionsCard extends StatelessWidget {
  const ProfileOptionsCard({super.key, required this.options});

  final List<ProfileOption> options;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      backgroundColor: Colors.white,
      borderRadius: 18,
      child: Column(
        children: [
          for (final option in options) ...[
            _ProfileOptionTile(option: option),
            if (option != options.last) const Divider(),
          ],
        ],
      ),
    );
  }
}

class LogoutCard extends StatelessWidget {
  const LogoutCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      backgroundColor: Colors.white,
      borderRadius: 18,
      child: _ProfileOptionTile(
        option: const ProfileOption(title: 'Logout', icon: Icons.logout),
        onTap: onTap,
        isDestructive: true,
      ),
    );
  }
}

class _ProfileOptionTile extends StatelessWidget {
  const _ProfileOptionTile({
    required this.option,
    this.onTap,
    this.isDestructive = false,
  });

  final ProfileOption option;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(option.icon, color: TwColors.primary),
      title: Text(
        option.title,
        style: TwText.fontBoldBase().copyWith(
          color: isDestructive ? TwColors.primary : null,
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
      onTap:
          onTap ??
          (option.route == null ? null : () => context.push(option.route!)),
    );
  }
}
