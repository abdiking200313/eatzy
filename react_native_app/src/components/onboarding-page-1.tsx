import { MaterialIcons } from '@expo/vector-icons';
import { Text, View } from 'react-native';

import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { radius, spacing } from '@/theme/tokens';

import { OnboardingPage } from './onboarding-page';
import { OutlinedCard } from './outlined-card';

type Restaurant = {
  name: string;
  etaMinutes: string;
  cuisine: string;
  distanceKm: string;
  rating: string;
};

// Sample/placeholder content for the mockup, not real data — mirrors
// onboarding_page_1.dart's private `_restaurants` list exactly.
const RESTAURANTS: Restaurant[] = [
  { name: 'Ayam Penyet Ria', etaMinutes: '20 min', cuisine: 'Malaysian', distanceKm: '0.4 km', rating: '4.8' },
  { name: 'Tokyo Ramen Bar', etaMinutes: '28 min', cuisine: 'Japanese', distanceKm: '0.9 km', rating: '4.6' },
  { name: 'Bangkok Wok', etaMinutes: '32 min', cuisine: 'Thai', distanceKm: '1.2 km', rating: '4.5' },
];

/**
 * Ports flutter_app/lib/features/onboarding/presentation/
 * onboarding_page_1.dart's `OnboardingPage1`: screen 1 of the onboarding
 * flow, "See What's Open Near You" — a distance chip above a short list of
 * nearby restaurants. Sample/placeholder content for the mockup, not real
 * data.
 */
export function OnboardingPage1() {
  return (
    <OnboardingPage
      title="See What's Open Near You"
      description="Browse the kitchens around your address, sorted by how fast they deliver."
      content={
        <View>
          <DistanceChip />
          <View style={{ height: spacing.x5 }} />
          {RESTAURANTS.map((restaurant, index) => (
            <View key={restaurant.name} style={{ marginTop: index > 0 ? spacing.x3 : 0 }}>
              <RestaurantCard restaurant={restaurant} />
            </View>
          ))}
        </View>
      }
    />
  );
}

function DistanceChip() {
  const colors = useSemanticColors();

  return (
    <View
      style={{
        alignSelf: 'flex-start',
        flexDirection: 'row',
        alignItems: 'center',
        paddingHorizontal: spacing.x4,
        paddingVertical: spacing.x2,
        borderRadius: radius.full,
        borderWidth: 1,
        borderColor: colors.border,
        backgroundColor: colors.card,
      }}>
      <View
        style={{
          width: 20,
          height: 20,
          borderRadius: 10,
          borderWidth: 1.5,
          borderColor: colors.primary,
          alignItems: 'center',
          justifyContent: 'center',
        }}>
        <MaterialIcons name="radar" size={12} color={colors.primary} />
      </View>
      <Text
        style={{ marginLeft: spacing.x2, flexShrink: 1 }}
        className="text-textSm font-outfitRegular text-text"
        numberOfLines={1}>
        Within <Text className="font-outfitSemiBold">1.5 km</Text> of you
      </Text>
    </View>
  );
}

function RestaurantCard({ restaurant }: { restaurant: Restaurant }) {
  return (
    <OutlinedCard padding={0}>
      <View style={{ paddingHorizontal: spacing.x4, paddingVertical: spacing.x3 }}>
        <View className="flex-row items-center">
          <Text
            style={{ flex: 1, marginRight: spacing.x2 }}
            className="text-fontBoldBase font-outfitSemiBold text-text"
            numberOfLines={1}>
            {restaurant.name}
          </Text>
          <Text className="text-fontBoldSm font-outfitSemiBold text-primary">{restaurant.etaMinutes}</Text>
        </View>
        <View style={{ height: spacing.x2 }} />
        <Text className="text-textSm font-outfitRegular text-text" numberOfLines={1}>
          {restaurant.cuisine} · {restaurant.distanceKm} · {restaurant.rating}
        </Text>
      </View>
    </OutlinedCard>
  );
}
