import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

class ProfileScreenFull extends StatefulWidget {
  const ProfileScreenFull({super.key});

  @override
  State<ProfileScreenFull> createState() => _ProfileScreenFullState();
}

class _ProfileScreenFullState extends State<ProfileScreenFull> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.epilogue(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryContainer,
              ),
              child: const Icon(Icons.person, size: 50),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Amara Johnson',
              style: GoogleFonts.epilogue(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            Text(
              'amara@example.com',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildProfileOption('My Orders', Icons.shopping_bag),
                  const Divider(),
                  _buildProfileOption('Addresses', Icons.location_on),
                  const Divider(),
                  _buildProfileOption('Payment Methods', Icons.payment),
                  const Divider(),
                  _buildProfileOption('Help & Support', Icons.help),
                  const Divider(),
                  _buildProfileOption('Settings', Icons.settings),
                  const Divider(),
                  _buildProfileOption('Logout', Icons.logout),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption(String title, IconData icon) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        title,
        style: GoogleFonts.epilogue(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {},
    );
  }
}
