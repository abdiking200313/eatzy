import { Text, View } from 'react-native';

import { OutlinedCard } from '@/components/outlined-card';
import { orderAddressLine, type OrderDetails } from '@/platform/activity/api/order-details';
import { spacing } from '@/theme/tokens';

/** Ports `OrderDetailsContent._hasDeliveryInfo`: whether there's anything for `DeliveryCard` to show. */
export function hasDeliveryInfo(order: OrderDetails): boolean {
  return orderAddressLine(order) != null || order.recipientName != null || order.phone != null || order.deliveryNote != null;
}

/**
 * Ports `flutter_app/lib/features/orders/presentation/widgets/delivery_card.dart`:
 * the delivery recipient, address, phone, and any note left for the
 * courier. Only rendered when `hasDeliveryInfo(order)`.
 */
export function DeliveryCard({ order }: { order: OrderDetails }) {
  const address = orderAddressLine(order);
  return (
    <OutlinedCard testID="delivery-card">
      <Text className="text-fontBoldSm font-outfitSemiBold text-text">Delivery address</Text>
      <View style={{ height: spacing.x2 }} />
      {order.recipientName != null && <Text className="text-textSm font-outfitRegular text-text">{order.recipientName}</Text>}
      {address != null && <Text className="text-textSm font-outfitRegular text-text">{address}</Text>}
      {order.phone != null && <Text className="text-textSm font-outfitRegular text-textMuted">{order.phone}</Text>}
      {order.deliveryNote != null && (
        <Text style={{ marginTop: spacing.x2 }} className="text-textSm font-outfitRegular text-textMuted">
          {order.deliveryNote}
        </Text>
      )}
    </OutlinedCard>
  );
}
