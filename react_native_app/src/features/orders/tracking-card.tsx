import { Text, View } from 'react-native';

import { OutlinedCard } from '@/components/outlined-card';
import { isOrderCancelled, orderStatusFlow, orderStatusLabel, orderStatusStep, type OrderDetails } from '@/platform/activity/api/order-details';
import { spacing } from '@/theme/tokens';

import { TimelineStepRow, type TimelineStep } from './timeline-step-row';

/** Ports `TrackingCard.build`'s step list, kept pure so it can be checked on its own. */
export function trackingSteps(order: OrderDetails): TimelineStep[] {
  if (isOrderCancelled(order)) {
    return [{ label: 'Order cancelled', isCompleted: true, hasConnector: false }];
  }
  const step = orderStatusStep(order);
  if (step < 0) {
    // A status this client doesn't know: show it as-is rather than guessing
    // where it sits in the flow.
    return [{ label: orderStatusLabel(order.summary.status), isCompleted: true, hasConnector: false }];
  }
  const flow = orderStatusFlow(order.summary.serviceId);
  return flow.map((status, index) => ({
    label: orderStatusLabel(status),
    isCompleted: index <= step,
    hasConnector: index < flow.length - 1,
  }));
}

/**
 * Ports `flutter_app/lib/features/orders/presentation/widgets/tracking_card.dart`:
 * order progress through the vertical's real status flow (the backend's
 * `advance_*_order_status` RPCs move an order along it).
 */
export function TrackingCard({ order, accent }: { order: OrderDetails; accent: string }) {
  return (
    <OutlinedCard testID="tracking-card">
      <Text className="text-fontBoldSm font-outfitSemiBold text-text">Track order</Text>
      <View style={{ height: spacing.x4 }} />
      {trackingSteps(order).map((step) => (
        <TimelineStepRow key={step.label} step={step} accent={accent} />
      ))}
    </OutlinedCard>
  );
}
