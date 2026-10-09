import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../platform/activity/models/order_details.dart';
import '../../../../widgets/app_cards.dart';
import 'timeline_step_row.dart';

/// Order progress through the vertical's real status flow (the
/// `advance_*_order_status` RPCs move an order along it).
class TrackingCard extends StatelessWidget {
  const TrackingCard({super.key, required this.order});

  final OrderDetails order;

  @override
  Widget build(BuildContext context) {
    final List<TimelineStep> steps;
    if (order.isCancelled) {
      steps = const [
        TimelineStep(
          label: 'Order cancelled',
          isCompleted: true,
          hasConnector: false,
        ),
      ];
    } else if (order.statusStep < 0) {
      // A status this client doesn't know: show it as-is rather than
      // guessing where it sits in the flow.
      steps = [
        TimelineStep(
          label: orderStatusLabel(order.status),
          isCompleted: true,
          hasConnector: false,
        ),
      ];
    } else {
      final flow = order.statusFlow;
      steps = [
        for (var i = 0; i < flow.length; i++)
          TimelineStep(
            label: orderStatusLabel(flow[i]),
            isCompleted: i <= order.statusStep,
            hasConnector: i < flow.length - 1,
          ),
      ];
    }
    return OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Track order', style: TwText.fontBoldSm),
          const SizedBox(height: TwSpacing.x4),
          for (final step in steps) TimelineStepRow(step: step),
        ],
      ),
    );
  }
}
