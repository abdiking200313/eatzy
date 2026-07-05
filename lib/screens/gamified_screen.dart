import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/app_misc.dart';
import '../widgets/app_scaffold.dart';

class GamifiedScreenFull extends StatelessWidget {
  const GamifiedScreenFull({super.key});

  static const int _userPoints = 2450;
  static const int _userLevel = 5;
  static const double _progressPercent = 0.65;

  static const List<_Badge> _badges = [
    _Badge(icon: Icons.shopping_bag_outlined, label: 'First Order', earned: true),
    _Badge(icon: Icons.local_fire_department_outlined, label: 'Hot Streak', earned: true),
    _Badge(icon: Icons.star_outlined, label: 'Top Rated', earned: true),
    _Badge(icon: Icons.card_giftcard_outlined, label: 'Lucky Draw'),
    _Badge(icon: Icons.diamond_outlined, label: 'Platinum'),
    _Badge(icon: Icons.stars, label: 'Legend'),
  ];

  static const List<_Reward> _rewards = [
    _Reward(
      title: 'Free Delivery',
      description: 'Use on next order',
      points: 500,
      color: AppColors.tertiary,
    ),
    _Reward(
      title: 'Discount Voucher',
      description: '20% off next meal',
      points: 750,
      color: AppColors.secondary,
    ),
    _Reward(
      title: 'Premium Membership',
      description: '1 month access',
      points: 1500,
      color: AppColors.primary,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Rewards & Achievements',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    style: AppTextStyles.labelBold().copyWith(
                      color: Colors.white.withOpacityValue(0.9),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '$_userPoints',
                    style: AppTextStyles.h1().copyWith(
                      fontSize: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: 'Redeem Rewards',
                    onPressed: () {},
                    color: Colors.white.withOpacityValue(0.2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Level $_userLevel', style: AppTextStyles.sectionTitle()),
                      Text('Level 6', style: AppTextStyles.bodySecondary()),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.full),
                    child: const LinearProgressIndicator(
                      value: _progressPercent,
                      minHeight: 8,
                      backgroundColor: AppColors.outlineVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${(_progressPercent * 100).toInt()}% to next level',
                    style: AppTextStyles.bodySecondary(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionTitle('Achievements'),
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
              itemCount: _badges.length,
              itemBuilder: (context, index) => _BadgeCard(badge: _badges[index]),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionTitle('Rewards Catalog'),
            const SizedBox(height: AppSpacing.md),
            for (final reward in _rewards) ...[
              _RewardCard(reward: reward),
              if (reward != _rewards.last) const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge});

  final _Badge badge;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      backgroundColor: badge.earned
          ? AppColors.surfaceContainerLow
          : AppColors.surfaceContainer,
      borderColor: badge.earned ? AppColors.primary : AppColors.outlineVariant,
      borderWidth: badge.earned ? 2 : 1,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            badge.icon,
            size: 32,
            color: badge.earned ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            badge.label,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSm().copyWith(
              color: badge.earned ? AppColors.onSurface : AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.reward});

  final _Reward reward;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: reward.color.withOpacityValue(0.2),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(Icons.card_giftcard_outlined, color: reward.color, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reward.title, style: AppTextStyles.cardTitleSm()),
                Text(reward.description, style: AppTextStyles.bodySecondary()),
              ],
            ),
          ),
          StatusPill(
            label: '${reward.points} pts',
            backgroundColor: reward.color.withOpacityValue(0.2),
            foregroundColor: reward.color,
          ),
        ],
      ),
    );
  }
}

class _Badge {
  const _Badge({
    required this.icon,
    required this.label,
    this.earned = false,
  });

  final IconData icon;
  final String label;
  final bool earned;
}

class _Reward {
  const _Reward({
    required this.title,
    required this.description,
    required this.points,
    required this.color,
  });

  final String title;
  final String description;
  final int points;
  final Color color;
}
