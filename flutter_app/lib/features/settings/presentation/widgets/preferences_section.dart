import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import 'setting_card.dart';

/// The Settings screen's "Preferences" section: Language / Currency /
/// Theme rows.
///
/// No language/currency/theme infrastructure exists yet, so these stay
/// non-interactive "coming soon" rows rather than implying settings that
/// don't do anything. That means this section needs no data or
/// callbacks from the screen, unlike [NotificationsSection]/[AccountSection].
class PreferencesSection extends StatelessWidget {
  const PreferencesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Preferences', style: TwText.sectionTitle),
        const SizedBox(height: TwSpacing.headerToContent),
        OutlinedCard(
          padding: EdgeInsets.zero,
          borderRadius: TwRadius.card,
          child: Column(
            children: const [
              SettingCard(
                title: 'Language',
                subtitle: 'Coming soon',
                icon: Icons.language_outlined,
              ),
              Divider(height: 1),
              SettingCard(
                title: 'Currency',
                subtitle: 'Coming soon',
                icon: Icons.attach_money_outlined,
              ),
              Divider(height: 1),
              SettingCard(
                title: 'Theme',
                subtitle: 'Coming soon',
                icon: Icons.brightness_7_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
