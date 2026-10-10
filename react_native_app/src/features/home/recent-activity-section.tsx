import { Fragment } from 'react';
import { Pressable, Text, View } from 'react-native';

import { ServiceIconChip } from '@/components/service-icon-chip';
import { StatusPill } from '@/components/status-pill';
import { formatCents } from '@/platform/money/format';
import { ServiceRegistry } from '@/platform/services/registry';
import type { ActivityItem } from '@/platform/activity/api/activity-item';
import { orderDetailsPath } from '@/platform/activity/api/activity-item';
import { forId } from '@/theme/service-theme';
import { rawColors, spacing } from '@/theme/tokens';

import { SectionHeader } from './section-header';

export type RecentActivitySectionProps = {
  items: ActivityItem[];
  onViewAll: () => void;
  onItemPress: (item: ActivityItem) => void;
};

/**
 * Ports `flutter_app/lib/features/super_app/presentation/widgets/recent_activity_section.dart`'s
 * `RecentActivitySection`: a preview of the 3 most recent cross-service
 * activity rows. The Dart source scopes an `ActivityController` listener
 * to just this widget; this port instead takes `items` as a plain prop --
 * the home screen owns fetching/refreshing them (no controller/store
 * ported for this preview, out of this issue's stated scope).
 */
export function RecentActivitySection({ items, onViewAll, onItemPress }: RecentActivitySectionProps) {
  const recentItems = items.slice(0, 3);
  if (recentItems.length === 0) {
    return null;
  }

  return (
    <View>
      <View style={{ paddingHorizontal: spacing.screenX }}>
        <SectionHeader title="Recent Activity" actionLabel="View all" onPress={onViewAll} />
      </View>
      <View style={{ paddingHorizontal: spacing.screenX }}>
        <RecentActivityListCard items={recentItems} onItemPress={onItemPress} />
      </View>
    </View>
  );
}

/**
 * The Recent Activity preview as a single white card containing every row,
 * with internal dividers between rows ("one card per list, not one card
 * per row").
 */
function RecentActivityListCard({ items, onItemPress }: { items: ActivityItem[]; onItemPress: (item: ActivityItem) => void }) {
  return (
    <View style={{ backgroundColor: rawColors.white, borderRadius: 12, paddingHorizontal: spacing.x3_5, paddingVertical: spacing.x1 }} className="shadow-card">
      {items.map((item, index) => (
        <Fragment key={item.id}>
          <RecentActivityRow item={item} onPress={() => onItemPress(item)} />
          {index < items.length - 1 && <View style={{ height: 1, backgroundColor: rawColors.stone200 }} />}
        </Fragment>
      ))}
    </View>
  );
}

function RecentActivityRow({ item, onPress }: { item: ActivityItem; onPress: () => void }) {
  const module = ServiceRegistry.byId(item.serviceId);
  const colors = forId(item.serviceId);
  const canOpen = orderDetailsPath(item) !== undefined;

  return (
    <Pressable
      accessibilityRole={canOpen ? 'button' : undefined}
      disabled={!canOpen}
      onPress={canOpen ? onPress : undefined}
      style={{ paddingVertical: spacing.listRowY }}
      className="flex-row items-start active:opacity-70">
      <ServiceIconChip icon={module.icon} background={colors.soft} foreground={colors.accent} size={42} borderRadius={13} iconSize={20} />
      <View style={{ marginLeft: spacing.x3_5 }} className="flex-1">
        <Text className="text-fontBoldSm">{item.title}</Text>
        <View style={{ height: 3 }} />
        <StatusPill label={item.status} backgroundColor={colors.soft} foregroundColor={colors.accent} fontSize={11} />
      </View>
      <View style={{ width: spacing.x2 }} />
      <Text className="text-fontBoldSm">{formatCents(item.amount)}</Text>
    </Pressable>
  );
}
