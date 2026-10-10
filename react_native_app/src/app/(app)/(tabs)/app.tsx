/**
 * Ports `flutter_app/lib/features/super_app/presentation/super_app_home_screen.dart`
 * (issue #373 / P4-02): the Home tab. Mirrors the Dart screen's own
 * `storeListingLoader`/`activityController` constructor-injection pattern
 * for testability with `storeListingLoader`/`fetchActivityPreview` props
 * here instead -- there's no `ActivityController`/query-cache layer
 * ported to react_native_app yet (out of this issue's stated scope), so
 * this screen owns its own load/retry state directly.
 */
import { router } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { ScrollView, View } from 'react-native';

import { HomeHeader } from '@/features/home/home-header';
import { PopularStoresSection, type PopularStoresLoadState } from '@/features/home/popular-stores-section';
import { PromoBanner } from '@/features/home/promo-banner';
import { RecentActivitySection } from '@/features/home/recent-activity-section';
import { SectionHeader } from '@/features/home/section-header';
import { ServiceGrid } from '@/features/home/service-grid';
import { orderDetailsPath, type ActivityItem } from '@/platform/activity/api/activity-item';
import { fetchActivities } from '@/platform/activity/api/activity-repository';
import type { StoreListing } from '@/platform/discovery/store-listing';
import { StoreListingRepository } from '@/platform/discovery/store-listing-repository';
import { AppRoutes } from '@/platform/navigation/app-routes';
import { ServiceRegistry } from '@/platform/services/registry';
import { spacing } from '@/theme/tokens';

export type HomeScreenProps = {
  storeListingLoader?: () => Promise<StoreListing[]>;
  fetchActivityPreview?: () => Promise<ActivityItem[]>;
};

const defaultStoreListingLoader = () => new StoreListingRepository().fetchStores({ limit: 10 });
const defaultFetchActivityPreview = () => fetchActivities(undefined, 3);

/** `router.replace`, not `push`: switches branches within the persistent bottom-nav shell instead of stacking a full-screen route over it. Mirrors the Dart source's `context.go`. */
function goTab(path: string) {
  router.replace(path as never);
}

export default function SuperAppHomeScreen({
  storeListingLoader = defaultStoreListingLoader,
  fetchActivityPreview = defaultFetchActivityPreview,
}: HomeScreenProps = {}) {
  const [storesState, setStoresState] = useState<PopularStoresLoadState>({ status: 'loading' });
  const [activityItems, setActivityItems] = useState<ActivityItem[]>([]);

  const fetchStores = useCallback(() => {
    storeListingLoader()
      .then((stores) => setStoresState({ status: 'data', stores }))
      .catch(() => setStoresState({ status: 'error' }));
  }, [storeListingLoader]);

  useEffect(() => {
    fetchStores();
  }, [fetchStores]);

  // A plain event handler (the retry button's `onPress`), not an effect
  // body -- unlike the initial load above, resetting to 'loading' here
  // synchronously is fine.
  const retryStores = useCallback(() => {
    setStoresState({ status: 'loading' });
    fetchStores();
  }, [fetchStores]);

  useEffect(() => {
    fetchActivityPreview()
      .then(setActivityItems)
      .catch(() => {
        // The preview just stays empty on failure -- this small widget has
        // no error/retry UI of its own, matching how the Dart screen never
        // surfaces `ActivityController.loadError` on this preview either.
      });
  }, [fetchActivityPreview]);

  return (
    <ScrollView contentContainerStyle={{ paddingBottom: spacing.x6 }}>
      <HomeHeader onSearch={() => goTab(AppRoutes.explore)} onNotifications={() => {}} onSettings={() => router.push(AppRoutes.settings as never)} />

      <View style={{ paddingHorizontal: spacing.screenX, paddingTop: spacing.x5 }}>
        <PromoBanner onExplore={() => goTab(AppRoutes.explore)} />
        <SectionHeader title="Categories" actionLabel="See all" onPress={() => router.push(AppRoutes.services as never)} />
        <ServiceGrid
          modules={ServiceRegistry.modules}
          onModulePress={(module) => goTab(module.entryRoute)}
          onMore={() => router.push(AppRoutes.services as never)}
        />
        <SectionHeader title="Popular Stores" actionLabel="View all" onPress={() => goTab(AppRoutes.explore)} />
      </View>

      <PopularStoresSection state={storesState} onRetry={retryStores} onStorePress={(store) => router.push(store.route as never)} />

      <RecentActivitySection
        items={activityItems}
        onViewAll={() => goTab(AppRoutes.activity)}
        onItemPress={(item) => {
          const path = orderDetailsPath(item);
          if (path) router.push(path as never);
        }}
      />
    </ScrollView>
  );
}
