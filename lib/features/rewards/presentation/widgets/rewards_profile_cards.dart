import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import '../models/reward_models.dart';

class AchievementCard extends StatelessWidget {
  const AchievementCard({super.key, required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      padding: const EdgeInsets.all(TwSpacing.x2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              achievement.icon,
              size: 26,
              color: achievement.unlocked
                  ? TwColors.primary
                  : TwColors.textMuted,
            ),
            const SizedBox(height: TwSpacing.rhythmTight),
            Text(
              achievement.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TwText.textXs.copyWith(
                color: achievement.unlocked
                    ? TwColors.text
                    : TwColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single leaderboard row. Rendered bare so [RewardsProfileScreen] can
/// compose several rows inside one shared [OutlinedCard] with internal
/// dividers — "one card per list, not one card per row" (#21/#27).
class LeaderboardCard extends StatelessWidget {
  const LeaderboardCard({super.key, required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TwSpacing.x4,
        vertical: TwSpacing.rhythmDefault,
      ),
      child: Row(
        children: [
          Text(
            '#${entry.rank}',
            style: TwText.textSm.copyWith(
              fontWeight: FontWeight.w700,
              color: entry.highlighted ? TwColors.primary : TwColors.text,
            ),
          ),
          const SizedBox(width: TwSpacing.rhythmTight),
          Expanded(
            child: Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TwText.fontBoldSm.copyWith(
                color: entry.highlighted ? TwColors.primary : TwColors.text,
              ),
            ),
          ),
          const SizedBox(width: TwSpacing.rhythmTight),
          Flexible(
            child: Text(
              entry.points,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TwText.textSm.copyWith(
                fontWeight: FontWeight.w700,
                color: TwColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
