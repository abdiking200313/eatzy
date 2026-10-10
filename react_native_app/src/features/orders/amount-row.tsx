import { Text, View } from 'react-native';

import { formatCents } from '@/platform/money/format';
import { spacing } from '@/theme/tokens';

export type AmountRowProps = {
  label: string;
  /** Integer cents. */
  cents: number;
  emphasize?: boolean;
};

/**
 * Ports `flutter_app/lib/features/orders/presentation/widgets/amount_row.dart`:
 * a single "label ... amount" line in `ItemsCard` (subtotal, delivery fee,
 * tax, or the bold total).
 */
export function AmountRow({ label, cents, emphasize = false }: AmountRowProps) {
  const textClass = emphasize ? 'text-fontBoldBase font-outfitSemiBold text-text' : 'text-textSm font-outfitRegular text-textMuted';
  return (
    <View style={{ marginBottom: spacing.x1 }} className="flex-row">
      <Text className={`flex-1 ${textClass}`}>{label}</Text>
      <Text className={textClass}>{formatCents(cents)}</Text>
    </View>
  );
}
