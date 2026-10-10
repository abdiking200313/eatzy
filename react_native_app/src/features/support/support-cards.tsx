import { MaterialIcons } from '@expo/vector-icons';
import { Text, View } from 'react-native';

import { ServiceIconChip } from '@/components/service-icon-chip';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { useServiceTheme } from '@/hooks/use-service-theme';
import { spacing } from '@/theme/tokens';

import type { FaqItem, SupportTopic } from './support-models';

/**
 * Ports flutter_app/lib/features/support/presentation/widgets/support_cards.dart.
 *
 * Each row is rendered bare so the support screen can compose several rows
 * inside one shared `OutlinedCard` with internal dividers -- "one card per
 * list, not one card per row". As in Flutter, the rows are display-only:
 * none of them is tappable and no contact action (mail/phone/chat link) is
 * wired up.
 *
 * `/support` sits outside any service module, so `context.serviceColors`
 * resolves to the neutral platform palette (`ServiceThemes.platform`).
 */
function TopicRow({ topic, trailingColor, testID }: { topic: SupportTopic; trailingColor: string; testID?: string }) {
  const palette = useServiceTheme('unknown');
  return (
    <View
      testID={testID}
      style={{ paddingHorizontal: spacing.x4, paddingVertical: spacing.x3_5 }}
      className="flex-row items-center">
      <ServiceIconChip
        icon={topic.icon}
        background={palette.soft}
        foreground={palette.accent}
        size={42}
        borderRadius={13}
      />
      <View style={{ width: spacing.x3_5 }} />
      <View className="flex-1">
        <Text className="text-fontBoldSm font-outfitSemiBold text-text">{topic.title}</Text>
        <View style={{ height: 3 }} />
        <Text className="text-textXs font-outfitMedium text-textMuted">{topic.subtitle}</Text>
      </View>
      <MaterialIcons name="arrow-forward" size={18} color={trailingColor} />
    </View>
  );
}

/** Ports `HelpCard`: a single help-topic row. */
export function HelpCard({ topic, testID }: { topic: SupportTopic; testID?: string }) {
  const colors = useSemanticColors();
  // Flutter's trailing arrow uses `colorScheme.onSurfaceVariant`, which the
  // app's `ColorScheme.light(...)` (lib/config/tailwind.dart) never sets, so
  // it falls back to `onSurface` = `TwColors.text`.
  return <TopicRow topic={topic} trailingColor={colors.text} testID={testID} />;
}

/** Ports `ContactCard`: a single contact-option row (accent-tinted arrow). */
export function ContactCard({ topic, testID }: { topic: SupportTopic; testID?: string }) {
  const palette = useServiceTheme('unknown');
  return <TopicRow topic={topic} trailingColor={palette.accent} testID={testID} />;
}

/** Ports `FaqCard`: a single FAQ entry (question over muted answer). */
export function FaqCard({ item, testID }: { item: FaqItem; testID?: string }) {
  return (
    <View testID={testID} style={{ paddingHorizontal: spacing.x4, paddingVertical: spacing.x3_5 }}>
      <Text className="text-fontBoldSm font-outfitSemiBold text-text">{item.question}</Text>
      <View style={{ height: spacing.x2 }} />
      <Text style={{ lineHeight: 13 * 1.5 }} className="text-textXs font-outfitMedium text-textMuted">
        {item.answer}
      </Text>
    </View>
  );
}
