import { Fragment, type ReactNode } from 'react';
import { ScrollView, View } from 'react-native';

import { AppScaffold } from '@/components/app-scaffold';
import { OutlinedCard } from '@/components/outlined-card';
import { SectionTitle } from '@/components/section-title';
import { ContactCard, FaqCard, HelpCard } from '@/features/support/support-cards';
import { CONTACT_OPTIONS, FAQ_ITEMS, HELP_TOPICS } from '@/features/support/support-content';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { radius, spacing } from '@/theme/tokens';

/**
 * Ports flutter_app/lib/features/support/presentation/support_screen.dart
 * (issue #403 / P8-07), served at `AppRoutes.support` ('/support').
 *
 * Like Flutter, the rows are display-only -- no mail/phone/chat action is
 * launched on tap.
 */
export default function SupportScreen() {
  return (
    <AppScaffold title="Help & Support" showBackButton>
      <ScrollView
        contentContainerStyle={{
          paddingHorizontal: spacing.x5,
          paddingTop: spacing.x5,
          paddingBottom: spacing.x6,
        }}>
        <SectionTitle title="How can we help?" />
        <View style={{ height: spacing.headerToContent }} />
        <DividedCard testID="support-help-topics">
          {HELP_TOPICS.map((topic) => (
            <HelpCard key={topic.title} topic={topic} />
          ))}
        </DividedCard>

        <View style={{ height: spacing.sectionGap }} />
        <SectionTitle title="Need more help?" />
        <View style={{ height: spacing.headerToContent }} />
        <DividedCard testID="support-contact-options">
          {CONTACT_OPTIONS.map((topic) => (
            <ContactCard key={topic.title} topic={topic} />
          ))}
        </DividedCard>

        <View style={{ height: spacing.sectionGap }} />
        <SectionTitle title="Frequently Asked Questions" />
        <View style={{ height: spacing.headerToContent }} />
        <DividedCard testID="support-faq">
          {FAQ_ITEMS.map((item) => (
            <FaqCard key={item.question} item={item} />
          ))}
        </DividedCard>
      </ScrollView>
    </AppScaffold>
  );
}

/**
 * One `OutlinedCard` (no padding, `TwRadius.card`) holding its rows with a
 * 1px divider between each -- Flutter's `Divider(height: 1)` -- but not
 * after the last.
 */
function DividedCard({ children, testID }: { children: ReactNode[]; testID: string }) {
  const colors = useSemanticColors();
  return (
    <OutlinedCard testID={testID} padding={0} borderRadius={radius.card}>
      {children.map((child, index) => (
        <Fragment key={index}>
          {child}
          {index < children.length - 1 && (
            <View testID={`${testID}-divider`} style={{ height: 1, backgroundColor: colors.border }} />
          )}
        </Fragment>
      ))}
    </OutlinedCard>
  );
}
