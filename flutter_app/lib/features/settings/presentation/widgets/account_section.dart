import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import 'setting_card.dart';

/// The Settings screen's "Account" section: Name / Phone Number / Date of
/// Birth / Email Address / Change Password rows, grouped in one shared
/// [OutlinedCard] with internal dividers.
///
/// Every subtitle is already resolved to its final display string by the
/// caller (loading/fallback text included) — this widget only lays the
/// rows out and wires their taps, matching how [NotificationsSection] stays
/// a plain presenter over data it doesn't own.
class AccountSection extends StatelessWidget {
  const AccountSection({
    super.key,
    required this.nameSubtitle,
    required this.phoneSubtitle,
    required this.dobSubtitle,
    required this.emailSubtitle,
    required this.onEditName,
    required this.onEditPhone,
    required this.onEditDob,
    required this.onEditEmail,
  });

  final String nameSubtitle;
  final String phoneSubtitle;
  final String dobSubtitle;
  final String emailSubtitle;
  final VoidCallback onEditName;
  final VoidCallback onEditPhone;
  final VoidCallback onEditDob;
  final VoidCallback onEditEmail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Account', style: TwText.sectionTitle),
        const SizedBox(height: TwSpacing.headerToContent),
        OutlinedCard(
          padding: EdgeInsets.zero,
          borderRadius: TwRadius.card,
          child: Column(
            children: [
              SettingCard(
                title: 'Name',
                subtitle: nameSubtitle,
                icon: Icons.person_outline,
                onTap: onEditName,
              ),
              const Divider(height: 1),
              SettingCard(
                title: 'Phone Number',
                subtitle: phoneSubtitle,
                icon: Icons.phone_outlined,
                onTap: onEditPhone,
              ),
              const Divider(height: 1),
              SettingCard(
                title: 'Date of Birth',
                subtitle: dobSubtitle,
                icon: Icons.cake_outlined,
                onTap: onEditDob,
              ),
              const Divider(height: 1),
              // An editable email flow exists (onEditEmail), so this row
              // is navigable rather than inert.
              SettingCard(
                title: 'Email Address',
                subtitle: emailSubtitle,
                icon: Icons.email_outlined,
                onTap: onEditEmail,
              ),
              const Divider(height: 1),
              SettingCard(
                title: 'Change Password',
                subtitle: 'Update your password',
                icon: Icons.lock_outlined,
                onTap: () => context.push(AppRoutes.resetPassword),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
