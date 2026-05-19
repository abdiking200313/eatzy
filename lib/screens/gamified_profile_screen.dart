import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';

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
