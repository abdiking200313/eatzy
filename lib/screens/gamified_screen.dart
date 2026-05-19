import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

class GamifiedScreenFull extends StatefulWidget {
  const GamifiedScreenFull({super.key});

  @override
  State<GamifiedScreenFull> createState() => _GamifiedScreenFullState();
}

class _GamifiedScreenFullState extends State<GamifiedScreenFull> {
  int userPoints = 2450;
  int userLevel = 5;
  double progressPercent = 0.65;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Rewards & Achievements',
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
              // Points Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: AppColors.fireSunGradient,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Column(
                  children: [
                    Text(
                      'Your Points',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacityValue(0.9),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '$userPoints',
                      style: GoogleFonts.epilogue(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacityValue(0.2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                          ),
                        ),
                        child: Text(
                          'Redeem Rewards',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Level Progress
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  border: Border.all(color: AppColors.outlineVariant),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Level $userLevel',
                          style: GoogleFonts.epilogue(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          'Level 6',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.full),
                      child: LinearProgressIndicator(
                        value: progressPercent,
                        minHeight: 8,
                        backgroundColor: AppColors.outlineVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${(progressPercent * 100).toInt()}% to next level',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Achievements Section
              Text(
                'Achievements',
                style: GoogleFonts.epilogue(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: 6,
                itemBuilder: (context, index) {
                  return _buildAchievementBadge(index);
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Rewards Catalog
              Text(
                'Rewards Catalog',
                style: GoogleFonts.epilogue(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildRewardItem(
                'Free Delivery',
                'Use on next order',
                500,
                AppColors.tertiary,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildRewardItem(
                'Discount Voucher',
                '20% off next meal',
                750,
                AppColors.secondary,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildRewardItem(
                'Premium Membership',
                '1 month access',
                1500,
                AppColors.primary,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementBadge(int index) {
    final badges = [
      {'icon': Icons.shopping_bag_outlined, 'label': 'First Order', 'earned': true},
      {'icon': Icons.local_fire_department_outlined, 'label': 'Hot Streak', 'earned': true},
      {'icon': Icons.star_outlined, 'label': 'Top Rated', 'earned': true},
      {'icon': Icons.card_giftcard_outlined, 'label': 'Lucky Draw', 'earned': false},
      {'icon': Icons.diamond_outlined, 'label': 'Platinum', 'earned': false},
      {'icon': Icons.star, 'label': 'Legend', 'earned': false},
    ];

    final badge = badges[index];
    final earned = badge['earned'] as bool;

    return Container(
      decoration: BoxDecoration(
        color: earned ? AppColors.surfaceContainerLow : AppColors.surfaceContainer,
        border: Border.all(
          color: earned ? AppColors.primary : AppColors.outlineVariant,
          width: earned ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            badge['icon'] as IconData,
            size: 32,
            color: earned ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            badge['label'] as String,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: earned ? AppColors.onSurface : AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardItem(
    String title,
    String description,
    int points,
    Color highlightColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: highlightColor.withOpacityValue(0.2),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(
              Icons.card_giftcard_outlined,
              color: highlightColor,
              size: 24,
            ),
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
                Text(
                  description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: highlightColor.withOpacityValue(0.2),
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: highlightColor),
            ),
            child: Text(
              '$points pts',
              style: GoogleFonts.epilogue(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: highlightColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
