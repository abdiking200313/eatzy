import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import '../../../../widgets/app_misc.dart';
import '../models/reward_models.dart';

class RewardBadgeCard extends StatelessWidget {
  const RewardBadgeCard({super.key, required this.badge});

  final RewardBadge badge;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return OutlinedCard(
      padding: const EdgeInsets.all(TwSpacing.x3),
      backgroundColor: badge.earned ? palette.soft : palette.card,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            badge.icon,
            size: 32,
            color: badge.earned ? palette.accent : TwColors.textMuted,
          ),
          const SizedBox(height: TwSpacing.x3),
          Text(
            badge.label,
            textAlign: TextAlign.center,
            style: TwText.textXs().copyWith(
              color: badge.earned ? TwColors.text : TwColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class RewardCard extends StatelessWidget {
  const RewardCard({super.key, required this.reward});

  final Reward reward;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      padding: const EdgeInsets.all(TwSpacing.x4),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: reward.color.withOpacityValue(0.2),
              borderRadius: BorderRadius.circular(TwRadius.md),
            ),
            child: Icon(
              Icons.card_giftcard_outlined,
              color: reward.color,
              size: 24,
            ),
          ),
          const SizedBox(width: TwSpacing.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reward.title, style: TwText.fontBoldSm()),
                Text(reward.description, style: TwText.textSm()),
              ],
            ),
          ),
          StatusPill(
            label: '${reward.points} pts',
            backgroundColor: reward.color.withOpacityValue(0.2),
            foregroundColor: reward.color,
          ),
          const SizedBox(width: TwSpacing.x2),
          Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
