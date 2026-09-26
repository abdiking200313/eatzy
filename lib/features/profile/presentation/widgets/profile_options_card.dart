import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import '../models/profile_models.dart';

class ProfileOptionsCard extends StatelessWidget {
  const ProfileOptionsCard({
    super.key,
    required this.options,
    this.onOptionTap,
  });

  final List<ProfileOption> options;

  /// Overrides each tile's default `context.push(option.route)` navigation
  /// when set, letting a caller react after returning from the pushed
  /// route — e.g. `ProfileScreen` reloading the profile header after a trip
  /// through Settings' profile-edit sheets.
  final void Function(BuildContext context, ProfileOption option)? onOptionTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      padding: EdgeInsets.zero,
      borderRadius: TwRadius.card,
      child: Column(
        children: [
          for (final option in options) ...[
            _ProfileOptionTile(option: option, onOptionTap: onOptionTap),
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
      borderRadius: TwRadius.card,
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
    this.onOptionTap,
    this.isDestructive = false,
  });

  final ProfileOption option;
  final VoidCallback? onTap;
  final void Function(BuildContext context, ProfileOption option)? onOptionTap;
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
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isDestructive ? colorScheme.errorContainer : palette.soft,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(option.icon, color: foreground, size: 20),
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
          (option.route == null
              ? null
              : () => onOptionTap != null
                    ? onOptionTap!(context, option)
                    : context.push(option.route!)),
    );
  }
}
