import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../platform/localization/app_money.dart';
import '../../../../widgets/app_cards.dart';
import '../../../../widgets/app_misc.dart';
import '../../../../widgets/app_scaffold.dart';
import '../../../cart/models/cart_item.dart';

class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({
    super.key,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.deliveryFee,
    required this.total,
  });

  final List<CartItem> items;
  final double subtotal;
  final double tax;
  final double deliveryFee;
  final double total;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return OutlinedCard(
      backgroundColor: palette.card,
      borderColor: palette.border,
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Order Summary', fontSize: 18),
          const SizedBox(height: TwSpacing.x5),
          for (final item in items) ...[
            _CheckoutItemRow(item: item),
            if (item != items.last) const SizedBox(height: TwSpacing.x4),
          ],
          const Divider(height: 32),
          SummaryRow(label: 'Subtotal', value: _formatCurrency(subtotal)),
          const SizedBox(height: TwSpacing.x5),
          SummaryRow(label: 'Tax', value: _formatCurrency(tax)),
          const SizedBox(height: TwSpacing.x4),
          SummaryRow(
            label: 'Delivery Fee',
            value: _formatCurrency(deliveryFee),
          ),
          const SizedBox(height: TwSpacing.x5),
          OutlinedCard(
            backgroundColor: palette.soft,
            borderColor: palette.border,
            borderRadius: 12,
            child: SummaryRow(
              label: 'Total',
              value: _formatCurrency(total),
              isBold: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutItemRow extends StatelessWidget {
  const _CheckoutItemRow({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: TwText.fontBoldSm),
              Text('x${item.quantity}', style: TwText.textSm),
            ],
          ),
        ),
        Text(
          _formatCurrency(item.total),
          style: TwText.fontBoldSm.copyWith(
            color: context.serviceColors.accent,
          ),
        ),
      ],
    );
  }
}

String _formatCurrency(num amount) {
  return AppMoney.format(amount);
}
