import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import 'setting_card.dart';

/// The Settings screen's "Support" section: About Us / Privacy Policy /
/// Terms & Conditions rows.
class SupportSection extends StatelessWidget {
  const SupportSection({super.key, required this.onAboutUsTap});

  final VoidCallback onAboutUsTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Support', style: TwText.sectionTitle),
        const SizedBox(height: TwSpacing.headerToContent),
        OutlinedCard(
          padding: EdgeInsets.zero,
          borderRadius: TwRadius.card,
          child: Column(
            children: [
              SettingCard(
                title: 'About Us',
                subtitle: 'Learn about Zivo',
                icon: Icons.info_outlined,
                onTap: onAboutUsTap,
              ),
              const Divider(height: 1),
              // Real in-app Privacy Policy / Terms screens now exist (issue
              // #37) — see PrivacyPolicyScreen/TermsOfServiceScreen for the
              // drafted text and their doc comments for the remaining
              // app-store hosted-URL gap.
              SettingCard(
                title: 'Privacy Policy',
                subtitle: 'How we handle your data',
                icon: Icons.privacy_tip_outlined,
                onTap: () => context.push(AppRoutes.privacyPolicy),
              ),
              const Divider(height: 1),
              SettingCard(
                title: 'Terms & Conditions',
                subtitle: 'Rules for using Zivo',
                icon: Icons.description_outlined,
                onTap: () => context.push(AppRoutes.termsOfService),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
