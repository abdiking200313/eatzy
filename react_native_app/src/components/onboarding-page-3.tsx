import { Text, View } from 'react-native';

import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { radius, rawColors, spacing } from '@/theme/tokens';

import { OnboardingPage } from './onboarding-page';
import { OutlinedCard } from './outlined-card';

type TimelineEntry = {
  label: string;
  time: string;
};

// Sample/placeholder tracking data for the mockup — mirrors
// onboarding_page_3.dart's private `_entries` list exactly.
const TIMELINE_ENTRIES: TimelineEntry[] = [
  { label: 'Order confirmed', time: '9:22 pm' },
  { label: 'Cooking', time: '9:28 pm' },
  { label: 'Rider picked up', time: '9:36 pm' },
];

// Two of the three stages (order confirmed, cooking) are already behind the
// rider being "on the way" with a live countdown, so two segments are filled
// and the final delivery leg is still in progress.
const SEGMENTS_FILLED = 2;
const SEGMENT_COUNT = 3;

const WHITE_70 = 'rgba(255, 255, 255, 0.7)';
const WHITE_15 = 'rgba(255, 255, 255, 0.15)';

/**
 * Ports flutter_app/lib/features/onboarding/presentation/
 * onboarding_page_3.dart's `OnboardingPage3`: screen 3 of the onboarding
 * flow, "Know Exactly When It Lands" — a dark delivery-status card with a
 * stage progress bar, plus a simple status timeline below it.
 * Sample/placeholder content for the mockup, not real tracking data.
 */
export function OnboardingPage3() {
  return (
    <OnboardingPage
      title="Know Exactly When It Lands"
      description="Live updates from the kitchen to your door, no guessing."
      content={
        <View>
          <DeliveryStatusCard />
          <View style={{ height: spacing.x5 }} />
          <StatusTimeline />
        </View>
      }
    />
  );
}

function DeliveryStatusCard() {
  return (
    <View
      style={{
        backgroundColor: rawColors.slate900,
        borderRadius: radius.xl,
        padding: spacing.x5,
      }}>
      <View className="flex-row items-center justify-between">
        <Text className="text-fontBoldBase font-outfitSemiBold" style={{ color: rawColors.white }}>
          On the way
        </Text>
        <Text className="text-fontBoldBase font-outfitSemiBold" style={{ color: rawColors.white }}>
          12 min
        </Text>
      </View>
      <View style={{ height: spacing.x4 }} />
      <View className="flex-row">
        {Array.from({ length: SEGMENT_COUNT }, (_, index) => (
          <View
            key={index}
            style={{ flex: 1, marginLeft: index > 0 ? spacing.x1 : 0 }}>
            <ProgressSegment filled={index < SEGMENTS_FILLED} />
          </View>
        ))}
      </View>
      <View style={{ height: spacing.x4 }} />
      <Text className="text-textSm font-outfitRegular" style={{ color: WHITE_70 }}>
        2 items from Ayam Penyet Ria
      </Text>
    </View>
  );
}

function ProgressSegment({ filled }: { filled: boolean }) {
  const colors = useSemanticColors();

  return (
    <View
      style={{
        height: 6,
        borderRadius: radius.full,
        backgroundColor: filled ? colors.primary : WHITE_15,
      }}
    />
  );
}

function StatusTimeline() {
  return (
    <OutlinedCard>
      {TIMELINE_ENTRIES.map((entry, index) => (
        <View key={entry.label} style={{ marginTop: index > 0 ? spacing.x3 : 0 }}>
          <TimelineRow entry={entry} isLatest={index === TIMELINE_ENTRIES.length - 1} />
        </View>
      ))}
    </OutlinedCard>
  );
}

function TimelineRow({ entry, isLatest }: { entry: TimelineEntry; isLatest: boolean }) {
  return (
    <View className="flex-row items-center justify-between">
      <Text
        className={
          isLatest ? 'text-fontBoldBase font-outfitSemiBold text-text' : 'text-textBase font-outfitRegular text-textMuted'
        }>
        {entry.label}
      </Text>
      <Text className="text-textSm font-outfitRegular text-textMuted">{entry.time}</Text>
    </View>
  );
}
