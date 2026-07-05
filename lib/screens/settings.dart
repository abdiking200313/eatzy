import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/app_scaffold.dart';

class SettingsScreenFull extends StatefulWidget {
  const SettingsScreenFull({super.key});

  @override
  State<SettingsScreenFull> createState() => _SettingsScreenFullState();
}

class _SettingsScreenFullState extends State<SettingsScreenFull> {
  bool pushNotifications = true;
  bool emailNotifications = false;
  bool promotionalEmails = true;
  bool orderUpdates = true;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Settings',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Notifications', fontSize: 18),
            const SizedBox(height: AppSpacing.md),
            _ToggleCard(
              title: 'Push Notifications',
              subtitle: 'Get notifications about your orders',
              value: pushNotifications,
              onChanged: (value) => setState(() => pushNotifications = value),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ToggleCard(
              title: 'Email Notifications',
              subtitle: 'Receive updates via email',
              value: emailNotifications,
              onChanged: (value) => setState(() => emailNotifications = value),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ToggleCard(
              title: 'Promotional Emails',
              subtitle: 'Get exclusive deals and offers',
              value: promotionalEmails,
              onChanged: (value) => setState(() => promotionalEmails = value),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ToggleCard(
              title: 'Order Updates',
              subtitle: 'Receive order status updates',
              value: orderUpdates,
              onChanged: (value) => setState(() => orderUpdates = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionTitle('Account', fontSize: 18),
            const SizedBox(height: AppSpacing.md),
            const _SettingCard(
              title: 'Email Address',
              subtitle: 'user@example.com',
              icon: Icons.email_outlined,
            ),
            const SizedBox(height: AppSpacing.sm),
            const _SettingCard(
              title: 'Phone Number',
              subtitle: '+1 234 567 8900',
              icon: Icons.phone_outlined,
            ),
            const SizedBox(height: AppSpacing.sm),
            const _SettingCard(
              title: 'Change Password',
              subtitle: 'Update your password',
              icon: Icons.lock_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionTitle('Preferences', fontSize: 18),
            const SizedBox(height: AppSpacing.md),
            const _SettingCard(
              title: 'Language',
              subtitle: 'English',
              icon: Icons.language_outlined,
            ),
            const SizedBox(height: AppSpacing.sm),
            const _SettingCard(
              title: 'Currency',
              subtitle: 'USD',
              icon: Icons.attach_money_outlined,
            ),
            const SizedBox(height: AppSpacing.sm),
            const _SettingCard(
              title: 'Theme',
              subtitle: 'Light',
              icon: Icons.brightness_7_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionTitle('Support', fontSize: 18),
            const SizedBox(height: AppSpacing.md),
            const _SettingCard(
              title: 'About Us',
              subtitle: 'Learn about ChowFlow',
              icon: Icons.info_outlined,
            ),
            const SizedBox(height: AppSpacing.sm),
            const _SettingCard(
              title: 'Privacy Policy',
              subtitle: 'Read our privacy policy',
              icon: Icons.privacy_tip_outlined,
            ),
            const SizedBox(height: AppSpacing.sm),
            const _SettingCard(
              title: 'Terms & Conditions',
              subtitle: 'Review our terms',
              icon: Icons.description_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Logout',
              onPressed: () {},
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
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
                Text(title, style: AppTextStyles.cardTitleSm()),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: AppTextStyles.labelSm().copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary,
              inactiveTrackColor: AppColors.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({
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
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.cardTitleSm()),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: AppTextStyles.labelSm().copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            color: AppColors.onSurfaceVariant,
            size: 16,
          ),
        ],
      ),
    );
  }
}
