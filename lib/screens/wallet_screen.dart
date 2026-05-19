import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';

class WalletScreenFull extends StatelessWidget {
  const WalletScreenFull({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'My Wallet',
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
          // Balance Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: AppColors.fireSunGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Balance',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.white.withOpacityValue(0.8),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                Text(
                  '₦15,750.50',
                  style: GoogleFonts.epilogue(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacityValue(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add,
                                color: Colors.white),
                            const SizedBox(width: AppSpacing.base),
                            Text(
                              'Add Money',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacityValue(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.send,
                                color: Colors.white),
                            const SizedBox(width: AppSpacing.base),
                            Text(
                              'Send',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Payment Methods
          Text(
            'Payment Methods',
            style: GoogleFonts.epilogue(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildPaymentMethod('Visa Card', '**** **** **** 4829', true),
          const SizedBox(height: AppSpacing.lg),
          _buildPaymentMethod('Master Card', '**** **** **** 2156', false),
          const SizedBox(height: AppSpacing.lg),
          _buildPaymentMethod('Bank Transfer', 'GTBank - Amara Johnson', false),
          const SizedBox(height: AppSpacing.xl),
          // Recent Transactions
          Text(
            'Recent Transactions',
            style: GoogleFonts.epilogue(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildTransaction(
            'Jollof Feast Order',
            'Order #45782',
            '-₦4,500',
            'https://lh3.googleusercontent.com/aida-public/AB6AXuDJUXE_bmcF9Zwpl-L25ghBB_DTvx3JZj5MZgzFOKW7p4H2TlIIAq2YJefUGpzVDnNN2vdro1kkmRqFY74fbiwRdWUuPHfAq_SMht1FSREf1nFUeqK5ResE9TzwgXUN5GBTckC-FWuNAyI04gt-K7i4XxAvQQxzpXlXl41A9lxyiYz2l4adWnwvjZhpQ21_EBnGKaZohJMO6S2AT6Jv6i57Lt2pbp9XBLFo5b9kcbV-S-Ei_p3ouce3gqr55Axa4fsbCfR59omjU4pW',
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildTransaction(
            'Wallet Top-up',
            '+₦10,000',
            '+₦10,000',
            null,
            isCredit: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod(String title, String subtitle, bool isDefault) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDefault
            ? Border.all(color: AppColors.primary, width: 2)
            : Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.payment, color: AppColors.primary),
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
          if (isDefault)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Default',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransaction(
    String title,
    String subtitle,
    String amount,
    String? imageUrl, {
    bool isCredit = false,
  }) {
    return Row(
      children: [
        if (imageUrl != null)
          CachedNetworkImage(
            imageUrl: imageUrl,
            imageBuilder: (context, imageProvider) =>
                CircleAvatar(
                  backgroundImage: imageProvider,
                  radius: 25,
                ),
            placeholder: (context, url) =>
                const CircleAvatar(radius: 25),
            errorWidget: (context, url, error) =>
                const CircleAvatar(radius: 25),
          )
        else
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(Icons.add,
                color: AppColors.onSurface),
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
        Text(
          amount,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isCredit ? AppColors.secondary : AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}
