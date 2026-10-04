import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../platform/localization/app_money.dart';

/// A single "label ... amount" line in [ItemsCard], e.g. subtotal, delivery
/// fee, tax, or the bold total.
class AmountRow extends StatelessWidget {
  const AmountRow({
    super.key,
    required this.label,
    required this.cents,
    this.emphasize = false,
  });

  final String label;
  final int cents;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? TwText.fontBoldBase
        : TwText.textSm.copyWith(color: TwColors.textMuted);
    return Padding(
      padding: const EdgeInsets.only(bottom: TwSpacing.x1),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(AppMoney.formatCents(cents), style: style),
        ],
      ),
    );
  }
}
