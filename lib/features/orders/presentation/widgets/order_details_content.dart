import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme.dart';
import '../../../../platform/activity/models/order_details.dart';
import '../../../../widgets/app_cards.dart';
import '../../../../widgets/app_misc.dart';
import 'delivery_card.dart';
import 'items_card.dart';
import 'tracking_card.dart';

/// The loaded-order body of `TrackOrderScreen`: header card, progress
/// timeline, items/charges, delivery info, payment, and the "Order again"
/// action, inside a pull-to-refresh list.
class OrderDetailsContent extends StatelessWidget {
  const OrderDetailsContent({
    super.key,
    required this.order,
    required this.onRefresh,
    this.orderAgainButton,
  });

  final OrderDetails order;
  final Future<void> Function() onRefresh;
  final Widget? orderAgainButton;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    final summary = order.summary;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          TwSpacing.x5,
          TwSpacing.x5,
          TwSpacing.x5,
          TwSpacing.x6,
        ),
        children: [
          OutlinedCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.storeName ?? summary.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TwText.fontBoldBase,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Order #${_shortId(order.id)}',
                        style: TwText.textXs.copyWith(
                          color: TwColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat(
                          'MMM d, yyyy · h:mm a',
                        ).format(summary.occurredAt.toLocal()),
                        style: TwText.textXs.copyWith(
                          color: TwColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: TwSpacing.x2),
                StatusPill(
                  label: orderStatusLabel(order.status),
                  backgroundColor: palette.soft,
                  foregroundColor: palette.accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: TwSpacing.sectionGap),
          TrackingCard(order: order),
          const SizedBox(height: TwSpacing.sectionGap),
          ItemsCard(order: order),
          if (_hasDeliveryInfo(order)) ...[
            const SizedBox(height: TwSpacing.sectionGap),
            DeliveryCard(order: order),
          ],
          if (summary.paymentMethodLabel case final methodLabel?) ...[
            const SizedBox(height: TwSpacing.sectionGap),
            OutlinedCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payment', style: TwText.fontBoldSm),
                        const SizedBox(height: TwSpacing.x2),
                        Text(methodLabel, style: TwText.textSm),
                      ],
                    ),
                  ),
                  if (summary.paymentStatusLabel case final statusLabel?)
                    StatusPill(
                      label: statusLabel,
                      backgroundColor: palette.soft,
                      foregroundColor: palette.accent,
                    ),
                ],
              ),
            ),
          ],
          if (orderAgainButton case final button?) ...[
            const SizedBox(height: TwSpacing.x6),
            SizedBox(width: double.infinity, child: button),
          ],
        ],
      ),
    );
  }

  static bool _hasDeliveryInfo(OrderDetails order) =>
      order.addressLine != null ||
      order.recipientName != null ||
      order.phone != null ||
      order.deliveryNote != null;

  /// UUID order ids are unreadable in full; the first block is enough to
  /// quote to support.
  static String _shortId(String id) {
    final head = id.split('-').first;
    return head.length >= 6 ? head.toUpperCase() : id;
  }
}
