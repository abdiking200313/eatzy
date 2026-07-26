import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../models/wallet_models.dart';

class WalletBalanceCard extends StatelessWidget {
  const WalletBalanceCard({
    super.key,
    required this.balance,
    required this.actions,
  });

  final String balance;
  final List<WalletAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TwSpacing.x8),
      decoration: BoxDecoration(
        gradient: TwColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Balance',
            style: TwText.textXs().copyWith(
              color: Colors.white.withOpacityValue(0.8),
            ),
          ),
          const SizedBox(height: TwSpacing.x2),
          Text(balance, style: TwText.text3xl().copyWith(color: Colors.white)),
          const SizedBox(height: TwSpacing.x8),
          Row(
            children: [
              for (final action in actions) ...[
                Expanded(child: _WalletActionButton(action: action)),
                if (action != actions.last) const SizedBox(width: TwSpacing.x5),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletActionButton extends StatelessWidget {
  const _WalletActionButton({required this.action});

  final WalletAction action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacityValue(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(action.icon, color: Colors.white),
          const SizedBox(width: TwSpacing.x2),
          Text(
            action.label,
            style: TwText.fontBoldSm().copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
