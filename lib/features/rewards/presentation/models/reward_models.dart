import 'package:flutter/material.dart';

class RewardBadge {
  const RewardBadge({
    required this.icon,
    required this.label,
    this.earned = false,
  });

  final IconData icon;
  final String label;
  final bool earned;
}

class Reward {
  const Reward({
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

class Achievement {
  const Achievement({
    required this.icon,
    required this.label,
    this.unlocked = false,
  });

  final IconData icon;
  final String label;
  final bool unlocked;
}

class LeaderboardEntry {
  const LeaderboardEntry({
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
