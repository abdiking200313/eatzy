import 'package:flutter/material.dart';

import '../../../../config/theme.dart';

/// A single settings row. Rendered bare (no card of its own) so a screen
/// can compose several rows inside one shared [OutlinedCard] with internal
/// dividers — "one card per list, not one card per row" (#21/#27).
///
/// The trailing chevron only renders when [onTap] is set (see #10) — a row
/// with no destination must not imply navigation that does nothing.
class SettingCard extends StatelessWidget {
  const SettingCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TwSpacing.x4,
        vertical: TwSpacing.x3_5,
      ),
      child: Row(
        children: [
          Icon(icon, color: TwColors.primary, size: 24),
          const SizedBox(width: TwSpacing.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TwText.fontBoldSm),
                const SizedBox(height: TwSpacing.x2),
                Text(
                  subtitle,
                  style: TwText.textXs.copyWith(color: TwColors.textMuted),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.arrow_forward_ios,
              color: TwColors.textMuted,
              size: 16,
            ),
        ],
      ),
    );

    if (onTap == null) return row;

    return InkWell(onTap: onTap, child: row);
  }
}
