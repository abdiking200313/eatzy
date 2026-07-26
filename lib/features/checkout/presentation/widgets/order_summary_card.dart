import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import '../../../../widgets/app_misc.dart';
import '../../../../widgets/app_scaffold.dart';
import '../../models/checkout_models.dart';

class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({super.key, required this.items});

  final List<CheckoutItem> items;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      backgroundColor: Colors.white,
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
          const SummaryRow(label: 'Subtotal', value: 'NGN 14,500'),
          const SizedBox(height: TwSpacing.x4),
          const SummaryRow(label: 'Tax', value: 'NGN 1,450'),
          const SizedBox(height: TwSpacing.x4),
          const SummaryRow(label: 'Delivery Fee', value: 'NGN 1,000'),
          const SizedBox(height: TwSpacing.x4),
          const _PromoCodeField(),
          const SizedBox(height: TwSpacing.x5),
          const OutlinedCard(
            backgroundColor: TwColors.cardMuted,
            borderColor: Colors.transparent,
            borderRadius: 12,
            child: SummaryRow(
              label: 'Total',
              value: 'NGN 16,950',
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

  final CheckoutItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: TwText.fontBoldSm()),
              Text('x${item.quantity}', style: TwText.textSm()),
            ],
          ),
        ),
        Text(
          item.price,
          style: TwText.fontBoldSm().copyWith(color: TwColors.primary),
        ),
      ],
    );
  }
}

class _PromoCodeField extends StatelessWidget {
  const _PromoCodeField();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TwSpacing.x4),
      decoration: BoxDecoration(
        color: TwColors.cardMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_offer_outlined, color: TwColors.primary),
          const SizedBox(width: TwSpacing.x3),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Enter promo code',
                hintStyle: TwText.textXs().copyWith(color: TwColors.textMuted),
                border: InputBorder.none,
              ),
            ),
          ),
          TextButton(
            onPressed: () {},
            child: Text('Apply', style: TwText.link()),
          ),
        ],
      ),
    );
  }
}
