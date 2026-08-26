import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../platform/localization/app_money.dart';
import '../../../../widgets/app_misc.dart';
import '../../models/wallet_payment_method_record.dart';
import '../../models/wallet_transaction_record.dart';

/// A single saved payment method row. Rendered bare so [WalletScreen] can
/// compose several rows inside one shared [OutlinedCard] with internal
/// dividers — "one card per list, not one card per row" (#21/#27).
class WalletPaymentMethodRow extends StatelessWidget {
  const WalletPaymentMethodRow({super.key, required this.method});

  final WalletPaymentMethodRecord method;

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
                Text(method.brand, style: TwText.fontBoldSm()),
                Text(
                  '**** **** **** ${method.lastFour}',
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

  final WalletTransactionRecord transaction;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    final isCredit = transaction.isCredit;
    final formattedAmount =
        '${isCredit ? '+' : '-'}${AppMoney.format(transaction.amount.abs())}';
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TwSpacing.x4,
        vertical: TwSpacing.rhythmDefault,
      ),
      child: Row(
        children: [
          ServiceIconChip(
            icon: isCredit ? Icons.arrow_downward : Icons.arrow_upward,
            background: palette.soft,
            foreground: palette.accent,
          ),
          const SizedBox(width: TwSpacing.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(transaction.description, style: TwText.fontBoldSm()),
                Text(
                  transaction.orderId != null
                      ? 'Order #${transaction.orderId}'
                      : _typeLabel(transaction.type),
                  style: TwText.textXs().copyWith(color: TwColors.textMuted),
                ),
              ],
            ),
          ),
          Text(
            formattedAmount,
            style: TwText.fontBoldSm().copyWith(
              color: isCredit ? TwColors.secondary : TwColors.text,
            ),
          ),
        ],
      ),
    );
  }

  static String _typeLabel(WalletTransactionType type) => switch (type) {
    WalletTransactionType.topUp => 'Top up',
    WalletTransactionType.orderPayment => 'Order payment',
    WalletTransactionType.refund => 'Refund',
    WalletTransactionType.adjustment => 'Adjustment',
  };
}
