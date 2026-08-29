import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
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
    final palette = context.serviceColors;
    final colorScheme = Theme.of(context).colorScheme;
    return AppScaffold(
      title: 'Rewards & Achievements',
      actions: [
        IconButton(
          tooltip: 'View rewards profile',
          icon: const Icon(Icons.person_outline),
          onPressed: () => context.push(AppRoutes.rewardsProfile),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(TwSpacing.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedCard(
              padding: const EdgeInsets.all(TwSpacing.x5),
              child: Column(
                children: [
                  Text(
                    'Your Points',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: TwSpacing.x2),
                  Text(
                    '$_userPoints',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(color: palette.accent),
                  ),
                  const SizedBox(height: TwSpacing.x4),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {},
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              'Redeem Rewards',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: TwSpacing.x2),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
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
                    children: [
                      Expanded(
                        child: Text(
                          'Level $_userLevel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TwText.textXl,
                        ),
                      ),
                      const SizedBox(width: TwSpacing.x2),
                      Text('Level 6', style: TwText.textSm),
                    ],
                  ),
                  const SizedBox(height: TwSpacing.x4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(TwRadius.full),
                    child: LinearProgressIndicator(
                      value: _progressPercent,
                      minHeight: 8,
                      backgroundColor: palette.border,
                      color: palette.accent,
                    ),
                  ),
                  const SizedBox(height: TwSpacing.x3),
                  Text(
                    '${(_progressPercent * 100).toInt()}% to next level',
                    style: TwText.textSm,
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
            const SizedBox(height: TwSpacing.rhythmSection),
            const SectionTitle('Rewards Catalog'),
            const SizedBox(height: TwSpacing.rhythmDefault),
            OutlinedCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final reward in _rewards) ...[
                    RewardCard(reward: reward),
                    if (reward != _rewards.last) const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
