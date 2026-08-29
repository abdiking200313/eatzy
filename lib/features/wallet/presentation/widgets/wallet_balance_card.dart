import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
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
    final palette = context.serviceColors;
    final textTheme = Theme.of(context).textTheme;
    return OutlinedCard(
      padding: const EdgeInsets.all(TwSpacing.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Balance',
            style: textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: TwSpacing.x2),
          Text(
            balance,
            style: textTheme.headlineSmall?.copyWith(color: palette.accent),
          ),
          const SizedBox(height: TwSpacing.x5),
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
    final palette = context.serviceColors;
    return Material(
      color: TwColors.card,
      borderRadius: BorderRadius.circular(TwRadius.lg),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(TwRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TwSpacing.x3,
            vertical: TwSpacing.x3,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: TwColors.border),
            borderRadius: BorderRadius.circular(TwRadius.lg),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  action.label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              const SizedBox(width: TwSpacing.x2),
              Icon(action.icon, color: palette.accent, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
