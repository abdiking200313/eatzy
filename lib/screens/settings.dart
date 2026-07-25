import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/app_router.dart';
import '../auth/auth_service.dart';
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

  Future<void> _logout() async {
    try {
      await AuthService().signOut();
      if (mounted) context.go(AppRoutes.login);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not log out: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Settings',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(TwSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Notifications', fontSize: 18),
            const SizedBox(height: TwSpacing.x4),
            _ToggleCard(
              title: 'Push Notifications',
              subtitle: 'Get notifications about your orders',
              value: pushNotifications,
              onChanged: (value) => setState(() => pushNotifications = value),
            ),
            const SizedBox(height: TwSpacing.x3),
            _ToggleCard(
              title: 'Email Notifications',
              subtitle: 'Receive updates via email',
              value: emailNotifications,
              onChanged: (value) => setState(() => emailNotifications = value),
            ),
            const SizedBox(height: TwSpacing.x3),
            _ToggleCard(
              title: 'Promotional Emails',
              subtitle: 'Get exclusive deals and offers',
              value: promotionalEmails,
              onChanged: (value) => setState(() => promotionalEmails = value),
            ),
            const SizedBox(height: TwSpacing.x3),
            _ToggleCard(
              title: 'Order Updates',
              subtitle: 'Receive order status updates',
              value: orderUpdates,
              onChanged: (value) => setState(() => orderUpdates = value),
            ),
            const SizedBox(height: TwSpacing.x5),
            const SectionTitle('Account', fontSize: 18),
            const SizedBox(height: TwSpacing.x4),
            const _SettingCard(
              title: 'Email Address',
              subtitle: 'user@example.com',
              icon: Icons.email_outlined,
            ),
            const SizedBox(height: TwSpacing.x3),
            const _SettingCard(
              title: 'Phone Number',
              subtitle: '+1 234 567 8900',
              icon: Icons.phone_outlined,
            ),
            const SizedBox(height: TwSpacing.x3),
            const _SettingCard(
              title: 'Change Password',
              subtitle: 'Update your password',
              icon: Icons.lock_outlined,
            ),
            const SizedBox(height: TwSpacing.x5),
            const SectionTitle('Preferences', fontSize: 18),
            const SizedBox(height: TwSpacing.x4),
            const _SettingCard(
              title: 'Language',
              subtitle: 'English',
              icon: Icons.language_outlined,
            ),
            const SizedBox(height: TwSpacing.x3),
            const _SettingCard(
              title: 'Currency',
              subtitle: 'USD',
              icon: Icons.attach_money_outlined,
            ),
            const SizedBox(height: TwSpacing.x3),
            const _SettingCard(
              title: 'Theme',
              subtitle: 'Light',
              icon: Icons.brightness_7_outlined,
            ),
            const SizedBox(height: TwSpacing.x5),
            const SectionTitle('Support', fontSize: 18),
            const SizedBox(height: TwSpacing.x4),
            const _SettingCard(
              title: 'About Us',
              subtitle: 'Learn about Zivo',
              icon: Icons.info_outlined,
            ),
            const SizedBox(height: TwSpacing.x3),
            const _SettingCard(
              title: 'Privacy Policy',
              subtitle: 'Read our privacy policy',
              icon: Icons.privacy_tip_outlined,
            ),
            const SizedBox(height: TwSpacing.x3),
            const _SettingCard(
              title: 'Terms & Conditions',
              subtitle: 'Review our terms',
              icon: Icons.description_outlined,
            ),
            const SizedBox(height: TwSpacing.x5),
            PrimaryButton(
              label: 'Logout',
              onPressed: _logout,
              color: TwColors.error,
            ),
            const SizedBox(height: TwSpacing.x5),
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
              activeColor: TwColors.primary,
              inactiveTrackColor: TwColors.textMuted,
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
