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
      padding: EdgeInsets.zero,
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
      padding: EdgeInsets.zero,
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
    final palette = context.serviceColors;
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = isDestructive
        ? colorScheme.error
        : colorScheme.onSurface;
    return ListTile(
      minTileHeight: 58,
      contentPadding: const EdgeInsets.symmetric(horizontal: TwSpacing.x4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDestructive ? colorScheme.errorContainer : palette.soft,
          borderRadius: BorderRadius.circular(TwRadius.md),
        ),
        child: Icon(option.icon, color: foreground, size: 19),
      ),
      title: Text(
        option.title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(color: foreground),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (option.trailingText != null)
            Text(
              option.trailingText!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(width: TwSpacing.x2),
          Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: isDestructive
                ? colorScheme.error
                : colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      onTap:
          onTap ??
          (option.route == null ? null : () => context.push(option.route!)),
    );
  }
}
