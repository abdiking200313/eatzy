import type { ReactNode } from 'react';
import { RefreshControl, ScrollView, Text, View } from 'react-native';

import { OutlinedCard } from '@/components/outlined-card';
import { StatusPill } from '@/components/status-pill';
import { paymentMethodLabel, paymentStatusLabel } from '@/platform/activity/api/activity-item';
import { orderStatusLabel, type OrderDetails } from '@/platform/activity/api/order-details';
import { formatOrderDateTime } from '@/platform/localization/date-format';
import type { ServiceThemeColors } from '@/theme/service-theme';
import { spacing } from '@/theme/tokens';

import { DeliveryCard, hasDeliveryInfo } from './delivery-card';
import { ItemsCard } from './items-card';
import { TrackingCard } from './tracking-card';

/**
 * Ports `OrderDetailsContent._shortId`: UUID order ids are unreadable in
 * full; the first block (upper-cased) is enough to quote to support.
 */
export function shortOrderId(id: string): string {
  const head = id.split('-')[0];
  return head.length >= 6 ? head.toUpperCase() : id;
}

export type OrderDetailsContentProps = {
  order: OrderDetails;
  palette: ServiceThemeColors;
  refreshing: boolean;
  onRefresh: () => void;
  orderAgainButton?: ReactNode;
};

/**
 * Ports `flutter_app/lib/features/orders/presentation/widgets/order_details_content.dart`:
 * the loaded-order body of the track-order screen -- header card, progress
 * timeline, items/charges, delivery info, payment, and the "Order again"
 * action -- inside a pull-to-refresh list. There is no courier assignment
 * anywhere in the schema, so no courier card or ETA is shown, and (like
 * Flutter) there is no customer cancel action.
 */
export function OrderDetailsContent({ order, palette, refreshing, onRefresh, orderAgainButton }: OrderDetailsContentProps) {
  const summary = order.summary;
  const methodLabel = paymentMethodLabel(summary);
  const statusLabel = paymentStatusLabel(summary);
  const gap = <View style={{ height: spacing.sectionGap }} />;

  return (
    <ScrollView
      testID="order-details-list"
      contentContainerStyle={{ padding: spacing.x5, paddingBottom: spacing.x6 }}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}>
      <OutlinedCard>
        <View className="flex-row items-start">
          <View className="flex-1">
            <Text numberOfLines={2} className="text-fontBoldBase font-outfitSemiBold text-text">
              {order.storeName ?? summary.title}
            </Text>
            <Text style={{ marginTop: 3 }} className="text-textXs font-outfitMedium text-textMuted">
              {`Order #${shortOrderId(summary.id)}`}
            </Text>
            <Text style={{ marginTop: 2 }} className="text-textXs font-outfitMedium text-textMuted">
              {formatOrderDateTime(summary.occurredAt)}
            </Text>
          </View>
          <View style={{ width: spacing.x2 }} />
          <StatusPill label={orderStatusLabel(summary.status)} backgroundColor={palette.soft} foregroundColor={palette.accent} />
        </View>
      </OutlinedCard>
      {gap}
      <TrackingCard order={order} accent={palette.accent} />
      {gap}
      <ItemsCard order={order} />
      {hasDeliveryInfo(order) && (
        <>
          {gap}
          <DeliveryCard order={order} />
        </>
      )}
      {methodLabel != null && (
        <>
          {gap}
          <OutlinedCard testID="payment-card">
            <View className="flex-row items-start">
              <View className="flex-1">
                <Text className="text-fontBoldSm font-outfitSemiBold text-text">Payment</Text>
                <Text style={{ marginTop: spacing.x2 }} className="text-textSm font-outfitRegular text-text">
                  {methodLabel}
                </Text>
              </View>
              {statusLabel != null && <StatusPill label={statusLabel} backgroundColor={palette.soft} foregroundColor={palette.accent} />}
            </View>
          </OutlinedCard>
        </>
      )}
      {orderAgainButton != null && <View style={{ marginTop: spacing.x6 }}>{orderAgainButton}</View>}
    </ScrollView>
  );
}
