import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/app_misc.dart';

class GamifiedProfileScreenFull extends StatelessWidget {
  const GamifiedProfileScreenFull({super.key});

  static const String _imageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAFRHg36EQATUqDhYD94R_K05G_f_-4ocNsdVBQUVTX8xvKbpdmSknU7GmZePTgv4lBF85k0RDyrmnlfs2PK53uCy3GJCX-D--qbu1fE71RUty6lSxYRFbaGWOOlbJXVqBEcr0UyXTpyWdZPmjRyEUF1OHHnMx-xCvUUimbd_auXDxH-k66vULm46he9xSs-oD00XaZzS3nF9H6yAXrF6_RTe3YZfKuK56TfbmvM9woXHeOrwZGm0mMP7mewgHD325vsNshlQvqaSTD';

  static const List<_Achievement> _achievements = [
    _Achievement(
      icon: Icons.emoji_events,
      label: 'First Order',
      unlocked: true,
    ),
    _Achievement(icon: Icons.star, label: 'Top Reviewer', unlocked: true),
    _Achievement(
      icon: Icons.local_fire_department,
      label: '7-Day Streak',
      unlocked: true,
    ),
    _Achievement(
      icon: Icons.workspace_premium,
      label: 'Premium Member',
      unlocked: true,
    ),
    _Achievement(icon: Icons.restaurant, label: 'Food Lover'),
    _Achievement(icon: Icons.military_tech, label: 'VIP'),
  ];

  static const List<_LeaderboardEntry> _leaders = [
    _LeaderboardEntry(
      rank: 1,
      name: 'Zainab Okafor',
      points: '12,450 pts',
      highlighted: true,
    ),
    _LeaderboardEntry(rank: 2, name: 'Your Rank', points: '8,250 pts'),
    _LeaderboardEntry(rank: 3, name: 'Chidi Ukaegbu', points: '7,890 pts'),
  ];

  @override
  Widget build(BuildContext context) {
    final progressWidth = (MediaQuery.of(context).size.width - 40) * 0.82;

    return Scaffold(
      backgroundColor: TwColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: TwColors.bg,
            elevation: 0,
            expandedHeight: 300,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: TwColors.primaryGradient,
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const NetworkAvatar(imageUrl: _imageUrl, radius: 50),
                      const SizedBox(height: TwSpacing.x5),
                      Text(
                        'Amara Johnson',
                        style: TwText.text2xl().copyWith(color: Colors.white),
                      ),
                      Text(
                        'Level 5 - Food Connoisseur',
                        style: TwText.textXs().copyWith(
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
              padding: const EdgeInsets.all(TwSpacing.x5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Experience Points', style: TwText.fontBoldSm()),
                  const SizedBox(height: TwSpacing.x1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('2,450/3,000', style: TwText.textSm()),
                      Text(
                        '82%',
                        style: TwText.fontBoldSm().copyWith(
                          color: TwColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: TwSpacing.x2),
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: TwColors.cardMuted,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Stack(
                      children: [
                        Container(
                          width: progressWidth,
                          decoration: BoxDecoration(
                            gradient: TwColors.primaryGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: TwSpacing.x8),
                  Text('Achievements', style: TwText.textXl()),
                  const SizedBox(height: TwSpacing.x5),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: TwSpacing.x5,
                          mainAxisSpacing: TwSpacing.x5,
                        ),
                    itemCount: _achievements.length,
                    itemBuilder: (context, index) =>
                        _AchievementCard(achievement: _achievements[index]),
                  ),
                  const SizedBox(height: TwSpacing.x8),
                  Text('Leaderboard', style: TwText.textXl()),
                  const SizedBox(height: TwSpacing.x5),
                  for (final entry in _leaders) ...[
                    _LeaderboardCard(entry: entry),
                    if (entry != _leaders.last)
                      const SizedBox(height: TwSpacing.x2),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});

  final _Achievement achievement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: achievement.unlocked ? TwColors.amber400 : TwColors.cardMuted,
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

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({required this.entry});

  final _LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TwSpacing.x5),
      decoration: BoxDecoration(
        color: entry.highlighted ? TwColors.amber400 : TwColors.cardMuted,
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

class _Achievement {
  const _Achievement({
    required this.icon,
    required this.label,
    this.unlocked = false,
  });

  final IconData icon;
  final String label;
  final bool unlocked;
}

class _LeaderboardEntry {
  const _LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.points,
    this.highlighted = false,
  });

  final int rank;
  final String name;
  final String points;
  final bool highlighted;
}
