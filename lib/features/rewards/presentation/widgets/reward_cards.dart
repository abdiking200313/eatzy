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
      padding: const EdgeInsets.all(TwSpacing.x2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              badge.icon,
              size: 28,
              color: badge.earned ? palette.accent : TwColors.textMuted,
            ),
            const SizedBox(height: TwSpacing.rhythmTight),
            Text(
              badge.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TwText.textXs.copyWith(
                color: badge.earned ? TwColors.text : TwColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single redeemable-reward row. Rendered bare so [RewardsScreen] can
/// compose several rows inside one shared [OutlinedCard] with internal
/// dividers — "one card per list, not one card per row" (#21/#27).
class RewardCard extends StatelessWidget {
  const RewardCard({super.key, required this.reward});

  final Reward reward;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TwSpacing.x4,
        vertical: TwSpacing.rhythmDefault,
      ),
      child: Row(
        children: [
          ServiceIconChip(
            icon: Icons.card_giftcard_outlined,
            background: reward.color.withOpacityValue(0.15),
            foreground: reward.color,
          ),
          const SizedBox(width: TwSpacing.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TwText.fontBoldSm,
                ),
                Text(
                  reward.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TwText.textSm,
                ),
              ],
            ),
          ),
          StatusPill(
            label: '${reward.points} pts',
            backgroundColor: reward.color.withOpacityValue(0.15),
            foregroundColor: reward.color,
            fontSize: 11,
          ),
          const SizedBox(width: TwSpacing.rhythmTight),
          Icon(
            Icons.arrow_forward_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
