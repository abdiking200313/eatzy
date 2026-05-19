import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

class SettingsScreenFull extends StatefulWidget {
  const SettingsScreenFull({Key? key}) : super(key: key);

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
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Settings',
          style: GoogleFonts.epilogue(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        foregroundColor: AppColors.onSurface,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notifications Section
              _buildSectionTitle('Notifications'),
              const SizedBox(height: AppSpacing.md),
              _buildToggleItem(
                'Push Notifications',
                'Get notifications about your orders',
                pushNotifications,
                (value) {
                  setState(() {
                    pushNotifications = value;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildToggleItem(
                'Email Notifications',
                'Receive updates via email',
                emailNotifications,
                (value) {
                  setState(() {
                    emailNotifications = value;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildToggleItem(
                'Promotional Emails',
                'Get exclusive deals and offers',
                promotionalEmails,
                (value) {
                  setState(() {
                    promotionalEmails = value;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildToggleItem(
                'Order Updates',
                'Receive order status updates',
                orderUpdates,
                (value) {
                  setState(() {
                    orderUpdates = value;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Account Section
              _buildSectionTitle('Account'),
              const SizedBox(height: AppSpacing.md),
              _buildSettingItem(
                'Email Address',
                'user@example.com',
                Icons.email_outlined,
                () {},
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildSettingItem(
                'Phone Number',
                '+1 234 567 8900',
                Icons.phone_outlined,
                () {},
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildSettingItem(
                'Change Password',
                'Update your password',
                Icons.lock_outlined,
                () {},
              ),
              const SizedBox(height: AppSpacing.lg),

              // Preferences Section
              _buildSectionTitle('Preferences'),
              const SizedBox(height: AppSpacing.md),
              _buildSettingItem(
                'Language',
                'English',
                Icons.language_outlined,
                () {},
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildSettingItem(
                'Currency',
                'USD',
                Icons.attach_money_outlined,
                () {},
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildSettingItem(
                'Theme',
                'Light',
                Icons.brightness_7_outlined,
                () {},
              ),
              const SizedBox(height: AppSpacing.lg),

              // Support Section
              _buildSectionTitle('Support'),
              const SizedBox(height: AppSpacing.md),
              _buildSettingItem(
                'About Us',
                'Learn about ChowFlow',
                Icons.info_outlined,
                () {},
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildSettingItem(
                'Privacy Policy',
                'Read our privacy policy',
                Icons.privacy_tip_outlined,
                () {},
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildSettingItem(
                'Terms & Conditions',
                'Review our terms',
                Icons.description_outlined,
                () {},
              ),
              const SizedBox(height: AppSpacing.lg),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                    ),
                  ),
                  child: Text(
                    'Logout',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.epilogue(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
    );
  }

  Widget _buildToggleItem(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.epilogue(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
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

  Widget _buildSettingItem(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          border: Border.all(color: AppColors.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.epilogue(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppColors.onSurfaceVariant,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

