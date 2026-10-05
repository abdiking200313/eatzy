import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../platform/activity/models/order_details.dart';
import '../../../../platform/localization/app_money.dart';
import '../../../../widgets/app_cards.dart';
import 'amount_row.dart';

/// The ordered line items plus subtotal/delivery fee/tax/total breakdown.
class ItemsCard extends StatelessWidget {
  const ItemsCard({super.key, required this.order});

  final OrderDetails order;

  @override
  Widget build(BuildContext context) {
    final tax = order.tax;
    return OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Items', style: TwText.fontBoldSm),
          const SizedBox(height: TwSpacing.x3),
          for (final line in order.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: TwSpacing.x2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      line.quantityLabel,
                      style: TwText.fontBoldSm.copyWith(
                        color: TwColors.textMuted,
                      ),
                    ),
                  ),
                  Expanded(child: Text(line.name, style: TwText.textSm)),
                  const SizedBox(width: TwSpacing.x2),
                  Text(
                    AppMoney.formatCents(line.lineTotal),
                    style: TwText.textSm,
                  ),
                ],
              ),
            ),
          const Divider(height: TwSpacing.x5),
          AmountRow(label: 'Subtotal', cents: order.subtotal),
          AmountRow(label: 'Delivery fee', cents: order.deliveryFee),
          if (tax != null && tax > 0) AmountRow(label: 'Tax', cents: tax),
          const SizedBox(height: TwSpacing.x1),
          AmountRow(label: 'Total', cents: order.total, emphasize: true),
        ],
      ),
    );
  }
}
