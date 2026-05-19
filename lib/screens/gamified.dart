import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';

export 'gamified_screen.dart';
export 'track_order_screen.dart';
export 'wallet_screen.dart';
export 'gamified_profile_screen.dart';
export 'support_screen.dart';

// This file acts as a barrel. Individual screen implementations live in the
// separate files above.

// ============= WALLET SCREEN =============
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

// ============= GAMIFIED PROFILE SCREEN =============
class GamifiedProfileScreenFull extends StatelessWidget {
  const GamifiedProfileScreenFull({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            expandedHeight: 300,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.fireSunGradient,
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CachedNetworkImage(
                        imageUrl:
                            'https://lh3.googleusercontent.com/aida-public/AB6AXuAFRHg36EQATUqDhYD94R_K05G_f_-4ocNsdVBQUVTX8xvKbpdmSknU7GmZePTgv4lBF85k0RDyrmnlfs2PK53uCy3GJCX-D--qbu1fE71RUty6lSxYRFbaGWOOlbJXVqBEcr0UyXTpyWdZPmjRyEUF1OHHnMx-xCvUUimbd_auXDxH-k66vULm46he9xSs-oD00XaZzS3nF9H6yAXrF6_RTe3YZfKuK56TfbmvM9woXHeOrwZGm0mMP7mewgHD325vsNshlQvqaSTD',
                        imageBuilder: (context, imageProvider) =>
                            CircleAvatar(
                          backgroundImage: imageProvider,
                          radius: 50,
                        ),
                        placeholder: (context, url) =>
                            const CircleAvatar(radius: 50),
                        errorWidget: (context, url, error) =>
                            const CircleAvatar(radius: 50),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Amara Johnson',
                        style: GoogleFonts.epilogue(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Level 5 - Food Connoisseur',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Colors.white.withOpacityValue(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  // Experience Bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Experience Points',
                            style: GoogleFonts.epilogue(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '2,450/3,000',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.base),
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Stack(
                          children: [
                            Container(
                              height: 12,
                              width:
                                  (MediaQuery.of(context).size.width - 40) *
                                      0.82,
                              decoration: BoxDecoration(
                                gradient: AppColors.fireSunGradient,
                                borderRadius:
                                    BorderRadius.circular(6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // Achievements
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Achievements',
                        style: GoogleFonts.epilogue(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: AppSpacing.lg,
                          mainAxisSpacing: AppSpacing.lg,
                        ),
                        itemCount: 6,
                        itemBuilder: (context, index) {
                          return _buildAchievementBadge(
                            ['🏆', '⭐', '🔥', '💎', '🎖️', '👑'][index],
                            ['First Order', 'Top Reviewer', '7-Day Streak',
                              'Premium Member', 'Food Lover', 'VIP'][index],
                            index < 4,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // Leaderboard
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Leaderboard',
                        style: GoogleFonts.epilogue(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _buildLeaderboardEntry(1, 'Zainab Okafor',
                          '12,450 pts', true),
                      const SizedBox(height: AppSpacing.base),
                      _buildLeaderboardEntry(2, 'Your Rank',
                          '8,250 pts', false),
                      const SizedBox(height: AppSpacing.base),
                      _buildLeaderboardEntry(3, 'Chidi Ukaegbu',
                          '7,890 pts', false),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementBadge(
    String emoji,
    String label,
    bool isUnlocked,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isUnlocked
            ? AppColors.secondaryContainer
            : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isUnlocked
                  ? AppColors.onSurface
                  : AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardEntry(
    int rank,
    String name,
    String points,
    bool isHighlighted,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppColors.secondaryContainer
            : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            '#$rank',
            style: GoogleFonts.epilogue(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isHighlighted
                  ? AppColors.onSurface
                  : AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.epilogue(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            points,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============= SUPPORT SCREEN =============
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
