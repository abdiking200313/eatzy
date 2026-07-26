import 'package:flutter/material.dart';

class WalletAction {
  const WalletAction({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class WalletPaymentMethod {
  const WalletPaymentMethod({
    required this.title,
    required this.subtitle,
    this.isDefault = false,
  });

  final String title;
  final String subtitle;
  final bool isDefault;
}

class WalletTransaction {
  const WalletTransaction({
    required this.title,
    required this.subtitle,
    required this.amount,
    this.imageUrl,
    this.isCredit = false,
  });

  final String title;
  final String subtitle;
  final String amount;
  final String? imageUrl;
  final bool isCredit;
}
