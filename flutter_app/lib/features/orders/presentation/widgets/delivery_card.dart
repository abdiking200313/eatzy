import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../platform/activity/models/order_details.dart';
import '../../../../widgets/app_cards.dart';

/// The delivery recipient, address, phone, and any note left for the
/// courier. Only rendered when the order has at least one of these fields.
class DeliveryCard extends StatelessWidget {
  const DeliveryCard({super.key, required this.order});

  final OrderDetails order;

  @override
  Widget build(BuildContext context) {
    final muted = TwText.textSm.copyWith(color: TwColors.textMuted);
    return OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delivery address', style: TwText.fontBoldSm),
          const SizedBox(height: TwSpacing.x2),
          if (order.recipientName case final name?)
            Text(name, style: TwText.textSm),
          if (order.addressLine case final address?)
            Text(address, style: TwText.textSm),
          if (order.phone case final phone?) Text(phone, style: muted),
          if (order.deliveryNote case final note?) ...[
            const SizedBox(height: TwSpacing.x2),
            Text(note, style: muted),
          ],
        ],
      ),
    );
  }
}
