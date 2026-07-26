import 'package:flutter/material.dart';

class ProfileOption {
  const ProfileOption({
    required this.title,
    required this.icon,
    this.route,
    this.trailingText,
  });

  final String title;
  final IconData icon;
  final String? route;
  final String? trailingText;
}

class ProfileStat {
  const ProfileStat({
    required this.icon,
    required this.title,
    required this.count,
    this.route,
  });

  final IconData icon;
  final String title;
  final String count;
  final String? route;
}
