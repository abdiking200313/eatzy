import { Text, View } from 'react-native';

import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { spacing } from '@/theme/tokens';

import { OnboardingPage } from './onboarding-page';
import { OutlinedCard } from './outlined-card';

type LineItem = {
  index: number;
  name: string;
  price: string;
};

// Sample/placeholder order data for the mockup — mirrors
// onboarding_page_2.dart's private `_items` list exactly.
const ITEMS: LineItem[] = [
  { index: 1, name: 'Ayam penyet set', price: '$6.40' },
  { index: 2, name: 'Iced lemon tea', price: '$3.20' },
];

/**
 * Ports flutter_app/lib/features/onboarding/presentation/
 * onboarding_page_2.dart's `OnboardingPage2`: screen 2 of the onboarding
 * flow, "Order In A Few Taps" — a single order-summary card.
 * Sample/placeholder content for the mockup, not real order data.
 */
export function OnboardingPage2() {
  return (
    <OnboardingPage
      title="Order In A Few Taps"
      description="Saved addresses and favourites, so a repeat order takes seconds."
      content={<OrderSummaryCard />}
    />
  );
}

function OrderSummaryCard() {
  const colors = useSemanticColors();

  return (
    <OutlinedCard>
      <View className="flex-row items-center">
        <Text
          style={{ flex: 1, marginRight: spacing.x2 }}
          className="text-fontBoldBase font-outfitSemiBold text-text"
          numberOfLines={1}>
          Ayam Penyet Ria
        </Text>
        <Text className="text-textSm font-outfitRegular text-textMuted">Bangsar</Text>
      </View>
      <View style={{ height: spacing.x4 }} />
      <View style={{ height: 1, backgroundColor: colors.border }} />
      <View style={{ height: spacing.x3 }} />
      {ITEMS.map((item, index) => (
        <View key={item.index} style={{ marginTop: index > 0 ? spacing.x3 : 0 }}>
          <LineItemRow item={item} />
        </View>
      ))}
      <View style={{ height: spacing.x3 }} />
      <View style={{ height: 1, backgroundColor: colors.border }} />
      <View style={{ height: spacing.x3 }} />
      <View className="flex-row items-center justify-between">
        <Text className="text-textSm font-outfitRegular text-textMuted">Total incl. delivery</Text>
        <Text className="text-fontBoldBase font-outfitSemiBold text-text">$11.60</Text>
      </View>
    </OutlinedCard>
  );
}

function LineItemRow({ item }: { item: LineItem }) {
  const colors = useSemanticColors();

  return (
    <View className="flex-row items-center">
      <View
        style={{
          width: 24,
          height: 24,
          borderRadius: 12,
          backgroundColor: colors.primarySoft,
          alignItems: 'center',
          justifyContent: 'center',
        }}>
        <Text className="text-textXs font-outfitSemiBold" style={{ color: colors.primary }}>
          {item.index}
        </Text>
      </View>
      <Text
        style={{ flex: 1, marginLeft: spacing.x3, marginRight: spacing.x2 }}
        className="text-textBase font-outfitRegular text-text"
        numberOfLines={1}>
        {item.name}
      </Text>
      <Text className="text-fontBoldSm font-outfitSemiBold text-text">{item.price}</Text>
    </View>
  );
}
