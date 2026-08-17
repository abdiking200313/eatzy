import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_scaffold.dart';
import '../../auth/data/auth_service.dart';
import 'widgets/setting_card.dart';
import 'widgets/toggle_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not log out: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Settings',
      showBackButton: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(TwSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Notifications', fontSize: 18),
            const SizedBox(height: TwSpacing.x4),
            ToggleCard(
              title: 'Push Notifications',
              subtitle: 'Get notifications about your orders',
              value: pushNotifications,
              onChanged: (value) => setState(() => pushNotifications = value),
            ),
            const SizedBox(height: TwSpacing.x3),
            ToggleCard(
              title: 'Email Notifications',
              subtitle: 'Receive updates via email',
              value: emailNotifications,
              onChanged: (value) => setState(() => emailNotifications = value),
            ),
            const SizedBox(height: TwSpacing.x3),
            ToggleCard(
              title: 'Promotional Emails',
              subtitle: 'Get exclusive deals and offers',
              value: promotionalEmails,
              onChanged: (value) => setState(() => promotionalEmails = value),
            ),
            const SizedBox(height: TwSpacing.x3),
            ToggleCard(
              title: 'Order Updates',
              subtitle: 'Receive order status updates',
              value: orderUpdates,
              onChanged: (value) => setState(() => orderUpdates = value),
            ),
            const SizedBox(height: TwSpacing.x5),
            const SectionTitle('Account', fontSize: 18),
            const SizedBox(height: TwSpacing.x4),
            const SettingCard(
              title: 'Email Address',
              subtitle: 'user@example.com',
              icon: Icons.email_outlined,
            ),
            const SizedBox(height: TwSpacing.x3),
            const SettingCard(
              title: 'Phone Number',
              subtitle: '+1 234 567 8900',
              icon: Icons.phone_outlined,
            ),
            const SizedBox(height: TwSpacing.x3),
            SettingCard(
              title: 'Change Password',
              subtitle: 'Update your password',
              icon: Icons.lock_outlined,
              onTap: () => context.push(AppRoutes.resetPassword),
            ),
            const SizedBox(height: TwSpacing.x5),
            const SectionTitle('Preferences', fontSize: 18),
            const SizedBox(height: TwSpacing.x4),
            const SettingCard(
              title: 'Language',
              subtitle: 'English',
              icon: Icons.language_outlined,
            ),
            const SizedBox(height: TwSpacing.x3),
            const SettingCard(
              title: 'Currency',
              subtitle: 'USD',
              icon: Icons.attach_money_outlined,
            ),
            const SizedBox(height: TwSpacing.x3),
            const SettingCard(
              title: 'Theme',
              subtitle: 'Light',
              icon: Icons.brightness_7_outlined,
            ),
            const SizedBox(height: TwSpacing.x5),
            const SectionTitle('Support', fontSize: 18),
            const SizedBox(height: TwSpacing.x4),
            const SettingCard(
              title: 'About Us',
              subtitle: 'Learn about Zivo',
              icon: Icons.info_outlined,
            ),
            const SizedBox(height: TwSpacing.x3),
            const SettingCard(
              title: 'Privacy Policy',
              subtitle: 'Read our privacy policy',
              icon: Icons.privacy_tip_outlined,
            ),
            const SizedBox(height: TwSpacing.x3),
            const SettingCard(
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
