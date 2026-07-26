import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_scaffold.dart';
import 'models/reward_models.dart';
import 'widgets/reward_cards.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  static const int _userPoints = 2450;
  static const int _userLevel = 5;
  static const double _progressPercent = 0.65;

  static const List<RewardBadge> _badges = [
    RewardBadge(
      icon: Icons.shopping_bag_outlined,
      label: 'First Order',
      earned: true,
    ),
    RewardBadge(
      icon: Icons.local_fire_department_outlined,
      label: 'Hot Streak',
      earned: true,
    ),
    RewardBadge(icon: Icons.star_outlined, label: 'Top Rated', earned: true),
    RewardBadge(icon: Icons.card_giftcard_outlined, label: 'Lucky Draw'),
    RewardBadge(icon: Icons.diamond_outlined, label: 'Platinum'),
    RewardBadge(icon: Icons.stars, label: 'Legend'),
  ];

  static const List<Reward> _rewards = [
    Reward(
      title: 'Free Delivery',
      description: 'Use on next order',
      points: 500,
      color: TwColors.tertiary,
    ),
    Reward(
      title: 'Discount Voucher',
      description: '20% off next meal',
      points: 750,
      color: TwColors.secondary,
    ),
    Reward(
      title: 'Premium Membership',
      description: '1 month access',
      points: 1500,
      color: TwColors.primary,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Rewards & Achievements',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(TwSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(TwSpacing.x5),
              decoration: BoxDecoration(
                gradient: TwColors.primaryGradient,
                borderRadius: BorderRadius.circular(TwRadius.lg),
              ),
              child: Column(
                children: [
                  Text(
                    'Your Points',
                    style: TwText.fontBoldSm().copyWith(
                      color: Colors.white.withOpacityValue(0.9),
                    ),
                  ),
                  const SizedBox(height: TwSpacing.x4),
                  Text(
                    '$_userPoints',
                    style: TwText.text3xl().copyWith(
                      fontSize: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: TwSpacing.x4),
                  PrimaryButton(
                    label: 'Redeem Rewards',
                    onPressed: () {},
                    color: Colors.white.withOpacityValue(0.2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: TwSpacing.x5),
            OutlinedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Level $_userLevel', style: TwText.textXl()),
                      Text('Level 6', style: TwText.textSm()),
                    ],
                  ),
                  const SizedBox(height: TwSpacing.x4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(TwRadius.full),
                    child: const LinearProgressIndicator(
                      value: _progressPercent,
                      minHeight: 8,
                      backgroundColor: TwColors.borderStrong,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        TwColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: TwSpacing.x3),
                  Text(
                    '${(_progressPercent * 100).toInt()}% to next level',
                    style: TwText.textSm(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: TwSpacing.x5),
            const SectionTitle('Achievements'),
            const SizedBox(height: TwSpacing.x4),
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
              itemBuilder: (context, index) =>
                  RewardBadgeCard(badge: _badges[index]),
            ),
            const SizedBox(height: TwSpacing.x5),
            const SectionTitle('Rewards Catalog'),
            const SizedBox(height: TwSpacing.x4),
            for (final reward in _rewards) ...[
              RewardCard(reward: reward),
              if (reward != _rewards.last) const SizedBox(height: TwSpacing.x4),
            ],
          ],
        ),
      ),
    );
  }
}
