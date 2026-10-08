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
