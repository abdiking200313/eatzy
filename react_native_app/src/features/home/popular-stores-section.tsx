import { MaterialIcons } from '@expo/vector-icons';
import { Pressable, ActivityIndicator, ScrollView, Text, View } from 'react-native';

import { OutlinedCard } from '@/components/outlined-card';
import { StoreListCard } from '@/components/store-list-card';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import type { StoreListing } from '@/platform/discovery/store-listing';
import { forId } from '@/theme/service-theme';
import { spacing } from '@/theme/tokens';

export type PopularStoresLoadState =
  | { status: 'loading' }
  | { status: 'error' }
  | { status: 'data'; stores: StoreListing[] };

export type PopularStoresSectionProps = {
  state: PopularStoresLoadState;
  onRetry: () => void;
  onStorePress: (store: StoreListing) => void;
};

/**
 * Ports `flutter_app/lib/features/super_app/presentation/widgets/popular_stores_section.dart`'s
 * `PopularStoresSection`. The Dart source wraps a `Stream`/`StreamBuilder`
 * with cached `initialData`; this takes a plain `state` prop instead --
 * the home screen itself (`src/app/(app)/(tabs)/app.tsx`) owns the
 * load/retry lifecycle, there's no query-cache layer ported yet for this
 * to peek at (out of this issue's stated scope).
 */
export function PopularStoresSection({ state, onRetry, onStorePress }: PopularStoresSectionProps) {
  if (state.status === 'loading') {
    return (
      <View style={{ height: 204 }} className="items-center justify-center">
        <ActivityIndicator />
      </View>
    );
  }

  if (state.status === 'error') {
    return <PopularStoresError onRetry={onRetry} />;
  }

  // A genuinely empty, non-error result just hides the section.
  if (state.stores.length === 0) {
    return null;
  }

  return (
    <ScrollView horizontal contentContainerStyle={{ paddingHorizontal: spacing.screenX, gap: spacing.carouselGap }} showsHorizontalScrollIndicator={false}>
      {state.stores.slice(0, 6).map((store) => (
        <View key={store.id} style={{ width: 212 }}>
          <StoreListCard
            testID={`popular-store-${store.id}`}
            name={store.name}
            subtitle={store.subtitle}
            imageUrl={store.imageUrl}
            accentColor={forId(store.serviceId).accent}
            onPress={() => onStorePress(store)}
          />
        </View>
      ))}
    </ScrollView>
  );
}

/**
 * Mirrors `_FoodHomeError`/`_StoreListError`'s card+retry shape, but with a
 * neutral accent rather than a service-specific one, since this section
 * mixes stores from every vertical.
 */
function PopularStoresError({ onRetry }: { onRetry: () => void }) {
  const colors = useSemanticColors();

  return (
    <View style={{ paddingHorizontal: spacing.screenX }}>
      <OutlinedCard>
        <View className="items-center">
          <MaterialIcons name="cloud-off" size={24} color={colors.primary} />
          <Text style={{ marginTop: spacing.x2 }} className="text-textBase text-text">
            Popular stores could not be loaded.
          </Text>
          <Pressable accessibilityRole="button" onPress={onRetry} style={{ marginTop: spacing.x4, minHeight: 44 }} className="items-center justify-center active:opacity-70">
            <Text className="text-button text-primary">Try again</Text>
          </Pressable>
        </View>
      </OutlinedCard>
    </View>
  );
}
