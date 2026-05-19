import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

class SupportScreenFull extends StatelessWidget {
  const SupportScreenFull({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Help & Support',
          style: GoogleFonts.epilogue(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Quick Help Section
          Text(
            'How can we help?',
            style: GoogleFonts.epilogue(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildHelpCard(
            Icons.shopping_bag_outlined,
            'Orders & Delivery',
            'Track orders, delivery issues',
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildHelpCard(
            Icons.payment,
            'Payment & Wallet',
            'Refunds, payment methods',
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildHelpCard(
            Icons.restaurant,
            'Restaurants & Food',
            'Menu, allergies, restaurant info',
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildHelpCard(
            Icons.account_circle_outlined,
            'Account',
            'Profile, login, passwords',
          ),
          const SizedBox(height: AppSpacing.xl),
          // Contact Support
          Text(
            'Need more help?',
            style: GoogleFonts.epilogue(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildContactOption(
            Icons.mail_outline,
            'Email Us',
            'support@chowflow.com',
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildContactOption(
            Icons.phone_outlined,
            'Call Us',
            '+234 XXX XXXX XXXX',
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildContactOption(
            Icons.chat_outlined,
            'Live Chat',
            'Chat with our team 9AM - 9PM',
          ),
          const SizedBox(height: AppSpacing.xl),
          // FAQ
          Text(
            'Frequently Asked Questions',
            style: GoogleFonts.epilogue(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildFAQItem(
            'How do I track my order?',
            'You can track your order in real-time from the Track Order section. You\'ll receive updates at each stage.',
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildFAQItem(
            'What if my food is late?',
            'If your order is delayed, contact our support team for immediate assistance and compensation.',
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildFAQItem(
            'Can I change my order?',
            'You can modify your order up to 2 minutes after placing it.',
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacityValue(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.epilogue(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactOption(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.fireSunGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacityValue(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.epilogue(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      value,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.white.withOpacityValue(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: GoogleFonts.epilogue(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            answer,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
