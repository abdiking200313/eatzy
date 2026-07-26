import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../models/reward_models.dart';

class AchievementCard extends StatelessWidget {
  const AchievementCard({super.key, required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: achievement.unlocked ? TwColors.blue400 : TwColors.cardMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            achievement.icon,
            size: 28,
            color: achievement.unlocked ? TwColors.text : TwColors.textMuted,
          ),
          const SizedBox(height: TwSpacing.x1),
          Text(
            achievement.label,
            textAlign: TextAlign.center,
            style: TwText.textXs().copyWith(
              color: achievement.unlocked ? TwColors.text : TwColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class LeaderboardCard extends StatelessWidget {
  const LeaderboardCard({super.key, required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TwSpacing.x5),
      decoration: BoxDecoration(
        color: entry.highlighted ? TwColors.blue400 : TwColors.cardMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            '#${entry.rank}',
            style: TwText.fontBoldSm().copyWith(
              color: entry.highlighted ? TwColors.text : TwColors.textMuted,
            ),
          ),
          const SizedBox(width: TwSpacing.x5),
          Expanded(child: Text(entry.name, style: TwText.fontBoldSm())),
          Text(
            entry.points,
            style: TwText.fontBoldSm().copyWith(color: TwColors.primary),
          ),
        ],
      ),
    );
  }
}
