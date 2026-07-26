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
    return OutlinedCard(
      backgroundColor: TwColors.cardMuted,
      borderColor: badge.earned ? TwColors.primary : TwColors.borderStrong,
      borderWidth: badge.earned ? 2 : 1,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            badge.icon,
            size: 32,
            color: badge.earned ? TwColors.primary : TwColors.textMuted,
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
        ],
      ),
    );
  }
}
