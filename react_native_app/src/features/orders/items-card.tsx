import { Text, View } from 'react-native';

import { OutlinedCard } from '@/components/outlined-card';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { orderLineQuantityLabel, orderLineTotal, type OrderDetails } from '@/platform/activity/api/order-details';
import { formatCents } from '@/platform/money/format';
import { spacing } from '@/theme/tokens';

import { AmountRow } from './amount-row';

/**
 * Ports `flutter_app/lib/features/orders/presentation/widgets/items_card.dart`:
 * the ordered line items plus the subtotal/delivery fee/tax/total breakdown
 * (tax only when present and above zero).
 */
export function ItemsCard({ order }: { order: OrderDetails }) {
  const colors = useSemanticColors();
  const tax = order.tax;
  return (
    <OutlinedCard testID="items-card">
      <Text className="text-fontBoldSm font-outfitSemiBold text-text">Items</Text>
      <View style={{ height: spacing.x3 }} />
      {order.lines.map((line, index) => (
        <View key={`${line.name}-${index}`} style={{ marginBottom: spacing.x2 }} className="flex-row items-start">
          <Text style={{ width: 52 }} className="text-fontBoldSm font-outfitSemiBold text-textMuted">
            {orderLineQuantityLabel(line)}
          </Text>
          <Text className="flex-1 text-textSm font-outfitRegular text-text">{line.name}</Text>
          <View style={{ width: spacing.x2 }} />
          <Text className="text-textSm font-outfitRegular text-text">{formatCents(orderLineTotal(line))}</Text>
        </View>
      ))}
      <View style={{ height: 1, backgroundColor: colors.border, marginVertical: (spacing.x5 - 1) / 2 }} />
      <AmountRow label="Subtotal" cents={order.subtotal} />
      <AmountRow label="Delivery fee" cents={order.deliveryFee} />
      {tax != null && tax > 0 && <AmountRow label="Tax" cents={tax} />}
      <View style={{ height: spacing.x1 }} />
      <AmountRow label="Total" cents={order.total} emphasize />
    </OutlinedCard>
  );
}
