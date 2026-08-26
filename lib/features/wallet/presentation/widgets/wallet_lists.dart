import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_misc.dart';
import '../models/wallet_models.dart';

/// A single saved payment method row. Rendered bare so [WalletScreen] can
/// compose several rows inside one shared [OutlinedCard] with internal
/// dividers — "one card per list, not one card per row" (#21/#27).
class WalletPaymentMethodRow extends StatelessWidget {
  const WalletPaymentMethodRow({super.key, required this.method});

  final WalletPaymentMethod method;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TwSpacing.x4,
        vertical: TwSpacing.rhythmDefault,
      ),
      child: Row(
        children: [
          ServiceIconChip(
            icon: Icons.payment_outlined,
            background: palette.soft,
            foreground: palette.accent,
          ),
          const SizedBox(width: TwSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(method.title, style: TwText.fontBoldSm()),
                Text(
                  method.subtitle,
                  style: TwText.textXs().copyWith(color: TwColors.textMuted),
                ),
              ],
            ),
          ),
          if (method.isDefault)
            StatusPill(
              label: 'Default',
              backgroundColor: palette.soft,
              foregroundColor: palette.accent,
              fontSize: 10,
            ),
        ],
      ),
    );
  }
}

/// A single wallet transaction row. Rendered bare so [WalletScreen] can
/// compose several rows inside one shared [OutlinedCard] with internal
/// dividers — "one card per list, not one card per row" (#21/#27).
class WalletTransactionRow extends StatelessWidget {
  const WalletTransactionRow({super.key, required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TwSpacing.x4,
        vertical: TwSpacing.rhythmDefault,
      ),
      child: Row(
        children: [
          if (transaction.imageUrl != null)
            NetworkAvatar(imageUrl: transaction.imageUrl!, radius: 24)
          else
            ServiceIconChip(
              icon: Icons.add,
              background: palette.soft,
              foreground: palette.accent,
            ),
          const SizedBox(width: TwSpacing.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(transaction.title, style: TwText.fontBoldSm()),
                Text(
                  transaction.subtitle,
                  style: TwText.textXs().copyWith(color: TwColors.textMuted),
                ),
              ],
            ),
          ),
          Text(
            transaction.amount,
            style: TwText.fontBoldSm().copyWith(
              color: transaction.isCredit ? TwColors.secondary : TwColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
