/**
 * Ports `flutter_app/lib/platform/activity/presentation/activity_screen.dart`
 * (issue #397 / P8-01): the Activity tab -- the user's orders across every
 * service, newest first, in one card with dividers between rows. Tapping a
 * real-service row opens its order details page (tracking, items, "Order
 * again"), pushed over the shell so back returns here.
 *
 * Beyond the Dart screen, this one keeps itself live: `useActivityFeed`
 * subscribes to Realtime changes on the user's order tables while mounted
 * and refreshes just the affected row, so a status change made in the
 * database appears without a pull-to-refresh (which stays as a fallback).
 */
import { router } from 'expo-router';
import { useCallback } from 'react';
import { FlashList } from '@shopify/flash-list';
import { Pressable, RefreshControl, Text, View } from 'react-native';
import type { StoreApi, UseBoundStore } from 'zustand';

import { AppScaffold } from '@/components/app-scaffold';
import { EmptyState } from '@/components/empty-state';
import { ErrorState } from '@/components/error-state';
import { LoadingState } from '@/components/loading-state';
import { ServiceIconChip } from '@/components/service-icon-chip';
import { StatusPill } from '@/components/status-pill';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { orderDetailsPath, type ActivityItem } from '@/platform/activity/api/activity-item';
import { useActivityFeed, type UseActivityFeedOptions } from '@/platform/activity/use-activity-feed';
import { formatCents } from '@/platform/money/format';
import { ServiceRegistry } from '@/platform/services/registry';
import { useActivityStore, type ActivityState } from '@/stores/activity-store';
import { useSessionStore } from '@/stores/session-store';
import { forId } from '@/theme/service-theme';
import { spacing } from '@/theme/tokens';

export type ActivityScreenProps = {
  title?: string;
  /** Test seam mirroring the Dart `controller` constructor param. */
  store?: UseBoundStore<StoreApi<ActivityState>>;
  /** Test seam: overrides the signed-in user id read from the session store. */
  userId?: string | null;
  /** Test seam: overrides the Realtime subscription. */
  watch?: UseActivityFeedOptions['watch'];
};

export default function ActivityScreen({ title = 'Activity', store = useActivityStore, userId: userIdOverride, watch }: ActivityScreenProps = {}) {
  const sessionUserId = useSessionStore((state) => state.userId);
  const userId = userIdOverride === undefined ? sessionUserId : userIdOverride;
  useActivityFeed({ store, userId, watch });

  const items = store((state) => state.items);
  const isLoading = store((state) => state.isLoading);
  const loadError = store((state) => state.loadError);
  const load = store((state) => state.load);
  const refresh = useCallback(() => void load(), [load]);

  let body;
  if (isLoading && items.length === 0) {
    body = <LoadingState />;
  } else if (loadError != null && items.length === 0) {
    body = <ErrorState message={loadError} onRetry={refresh} />;
  } else {
    body = (
      <FlashList
        testID="activity-list"
        data={items}
        keyExtractor={(item) => item.id}
        contentContainerStyle={
          items.length === 0 ? { flexGrow: 1 } : { paddingHorizontal: spacing.x5, paddingTop: spacing.x5, paddingBottom: spacing.x6 }
        }
        refreshControl={<RefreshControl refreshing={isLoading} onRefresh={refresh} />}
        ListEmptyComponent={<EmptyState icon="receipt-long" title="No activity yet" message="Your orders and bookings will appear here." />}
        renderItem={({ item, index }) => <ActivityListSegment item={item} isFirst={index === 0} isLast={index === items.length - 1} />}
      />
    );
  }

  return <AppScaffold title={title}>{body}</AppScaffold>;
}

/**
 * One row of the feed's single card ("one card per list, not one card per
 * row"). The list is virtualized (issue #417), so the card can no longer be
 * one wrapping `View`: each row paints its own slice of the card -- rounded
 * top corners on the first row, rounded bottom corners plus no trailing
 * divider on the last -- which composes back into the same single card.
 * Per-service accent stays confined to each row's icon chip, pill and amount.
 */
function ActivityListSegment({ item, isFirst, isLast }: { item: ActivityItem; isFirst: boolean; isLast: boolean }) {
  const colors = useSemanticColors();
  return (
    <View
      style={{
        backgroundColor: colors.card,
        borderTopLeftRadius: isFirst ? 12 : 0,
        borderTopRightRadius: isFirst ? 12 : 0,
        borderBottomLeftRadius: isLast ? 12 : 0,
        borderBottomRightRadius: isLast ? 12 : 0,
        overflow: 'hidden',
      }}
      className="shadow-card">
      <ActivityRow item={item} />
      {!isLast && <View style={{ height: 1, backgroundColor: colors.border }} />}
    </View>
  );
}

function ActivityRow({ item }: { item: ActivityItem }) {
  const semantic = useSemanticColors();
  const module = ServiceRegistry.byId(item.serviceId);
  const colors = forId(item.serviceId);
  const path = orderDetailsPath(item);

  return (
    <Pressable
      accessibilityRole={path ? 'button' : undefined}
      disabled={!path}
      onPress={path ? () => router.push(path as never) : undefined}
      style={{ paddingHorizontal: spacing.x4, paddingVertical: spacing.x3_5 }}
      className="flex-row items-start active:opacity-70">
      <ServiceIconChip icon={module.icon} background={colors.accent} foreground={colors.onAccent} size={42} borderRadius={13} iconSize={20} />
      <View style={{ marginLeft: spacing.x3_5 }} className="flex-1">
        <Text className="text-fontBoldSm">{item.title}</Text>
        <View style={{ height: 3 }} />
        <View style={{ gap: spacing.x2 }} className="flex-row flex-wrap items-center">
          {item.subtitle ? <Text style={{ color: semantic.textMuted }} className="text-textXs">{item.subtitle}</Text> : null}
          <StatusPill label={item.status} backgroundColor={colors.soft} foregroundColor={colors.accent} />
        </View>
      </View>
      <View style={{ width: spacing.x2 }} />
      <Text style={{ color: colors.accent }} className="text-fontBoldSm">
        {formatCents(item.amount)}
      </Text>
    </Pressable>
  );
}
