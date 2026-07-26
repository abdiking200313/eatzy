import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';

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
    return OutlinedCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TwText.fontBoldSm()),
                const SizedBox(height: TwSpacing.x1),
                Text(
                  subtitle,
                  style: TwText.textXs().copyWith(color: TwColors.textMuted),
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
