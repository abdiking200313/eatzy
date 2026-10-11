import { ScrollView, Text, View } from 'react-native';

import { AppScaffold } from '@/components/app-scaffold';
import { spacing } from '@/theme/tokens';

import type { LegalDocument } from './legal-document';

/**
 * Ports `LegalDocumentScreen` from
 * flutter_app/lib/features/legal/presentation/legal_document_screen.dart:
 * renders any `LegalDocument` as a scrollable, read-only screen so the
 * Privacy Policy and Terms screens share one layout.
 *
 * In-app only: app-store submission additionally needs a hosted external
 * URL -- see docs/legal/ for the same text ready to publish elsewhere.
 */
export function LegalDocumentScreen({ document }: { document: LegalDocument }) {
  return (
    <AppScaffold title={document.title} showBackButton>
      <ScrollView contentContainerStyle={{ padding: spacing.x5 }}>
        <Text className="text-textXs font-outfitMedium text-textMuted">
          {`Effective ${document.effectiveDate}`}
        </Text>
        <View style={{ height: spacing.x3_5 }} />
        <Text className="text-textSm font-outfitRegular text-text">{document.intro}</Text>
        {document.sections.map((section) => (
          <View key={section.heading}>
            <View style={{ height: spacing.sectionGap }} />
            {/* Flutter: TwText.fontBoldSm.copyWith(fontSize: 16). */}
            <Text
              accessibilityRole="header"
              style={{ fontSize: 16 }}
              className="text-fontBoldSm font-outfitSemiBold text-text">
              {section.heading}
            </Text>
            <View style={{ height: spacing.x2 }} />
            <Text className="text-textSm font-outfitRegular text-text">{section.body}</Text>
          </View>
        ))}
        <View style={{ height: spacing.x5 }} />
      </ScrollView>
    </AppScaffold>
  );
}
