import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import '../../../../widgets/app_misc.dart';
import '../models/wallet_models.dart';

class WalletPaymentMethodCard extends StatelessWidget {
  const WalletPaymentMethodCard({super.key, required this.method});

  final WalletPaymentMethod method;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return OutlinedCard(
      padding: const EdgeInsets.all(TwSpacing.x4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: BorderRadius.circular(TwRadius.md),
            ),
            child: Icon(
              Icons.payment_outlined,
              color: palette.accent,
              size: 20,
            ),
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

class WalletTransactionRow extends StatelessWidget {
  const WalletTransactionRow({super.key, required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (transaction.imageUrl != null)
          NetworkAvatar(imageUrl: transaction.imageUrl!, radius: 25)
        else
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: TwColors.blue400,
              borderRadius: BorderRadius.circular(TwRadius.full),
            ),
            child: const Icon(Icons.add, color: TwColors.text),
          ),
        const SizedBox(width: TwSpacing.x5),
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
    );
  }
}
