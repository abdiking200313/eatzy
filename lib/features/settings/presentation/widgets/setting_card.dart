import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';

class SettingCard extends StatelessWidget {
  const SettingCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      child: Row(
        children: [
          Icon(icon, color: TwColors.primary, size: 24),
          const SizedBox(width: TwSpacing.x4),
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
          const Icon(
            Icons.arrow_forward_ios,
            color: TwColors.textMuted,
            size: 16,
          ),
        ],
      ),
    );
  }
}
