import 'package:flutter/material.dart';

import '../../../../config/theme.dart';

/// A single toggle row. Rendered bare (no card of its own) so a screen can
/// compose several rows inside one shared `OutlinedCard` with internal
/// dividers — "one card per list, not one card per row" (#21/#27).
class ToggleCard extends StatelessWidget {
  const ToggleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TwSpacing.x4,
        vertical: TwSpacing.rhythmDefault,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TwText.fontBoldSm),
                const SizedBox(height: TwSpacing.rhythmTight),
                Text(
                  subtitle,
                  style: TwText.textXs.copyWith(color: TwColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: TwSpacing.x4),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: TwColors.primary,
              inactiveTrackColor: TwColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
