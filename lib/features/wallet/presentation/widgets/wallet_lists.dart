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
    return OutlinedCard(
      backgroundColor: Colors.white,
      borderRadius: 16,
      borderColor: method.isDefault ? TwColors.primary : TwColors.borderStrong,
      borderWidth: method.isDefault ? 2 : 1,
      child: Row(
        children: [
          const Icon(Icons.payment, color: TwColors.primary),
          const SizedBox(width: TwSpacing.x5),
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
            const StatusPill(
              label: 'Default',
              backgroundColor: TwColors.primary,
              foregroundColor: Colors.white,
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
