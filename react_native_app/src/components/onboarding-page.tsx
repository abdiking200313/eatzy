import type { ReactNode } from 'react';
import { ScrollView, Text, useWindowDimensions, View } from 'react-native';

import { spacing } from '@/theme/tokens';

export type OnboardingPageProps = {
  /**
   * The per-screen illustration area (e.g. a restaurant list, an order
   * summary card, or a delivery-tracking card).
   */
  content: ReactNode;
  title: string;
  description: string;
};

// Mirrors onboarding_page.dart's own fixed clearances: the welcome screen's
// transparent app bar (status-bar inset + a toolbar) above this content, and
// the pinned dots + "Get Started" + "Log In" row (see welcome.tsx) below it.
// Flutter derives the header half from `MediaQuery.paddingOf(context).top`
// (the real status-bar inset); this uses a flat estimate instead of
// `useSafeAreaInsets` so this presentational component doesn't require a
// `SafeAreaProvider` ancestor just to render a slide in isolation (e.g. in a
// component test) — welcome.tsx's own `SafeAreaView`s already keep the real
// pinned header/footer clear of the notch/home-indicator; this is only an
// approximation of how much of this slide's own content they cover.
const HEADER_CLEARANCE = 80;
const BOTTOM_CLEARANCE = 192;

/**
 * Ports flutter_app/lib/features/onboarding/presentation/widgets/
 * onboarding_page.dart's `OnboardingPage`: a reusable onboarding slide
 * layout — a per-screen illustration/content area on top, then a headline
 * and a muted description below it, vertically centered in the space above
 * the welcome screen's pinned bottom controls.
 *
 * The Dart widget computes an exact pixel `headerClearance`/`bottomClearance`
 * padding pair from `MediaQuery` so the content block centers precisely
 * between the transparent app bar and the pinned dots/button/login row. This
 * port reaches the same visual result with plain flexbox centering instead
 * (a `minHeight` scroll container with `justifyContent: 'center'`, offset by
 * the same two clearances) rather than reproducing the Dart math line-for-
 * line — there is no RN equivalent of Flutter's `TextScaler`-driven
 * clearance growth, so this clearance is a fixed constant (see the comment
 * on {@link HEADER_CLEARANCE} above for why it's not safe-area-aware either).
 */
export function OnboardingPage({ content, title, description }: OnboardingPageProps) {
  const { height } = useWindowDimensions();

  return (
    <ScrollView
      contentContainerStyle={{ minHeight: height, justifyContent: 'center' }}
      showsVerticalScrollIndicator={false}>
      <View
        testID="onboarding-block"
        style={{ paddingTop: HEADER_CLEARANCE, paddingBottom: BOTTOM_CLEARANCE }}>
        <View style={{ paddingHorizontal: spacing.x5 }}>{content}</View>
        <View style={{ height: spacing.x8 }} />
        <View style={{ paddingHorizontal: spacing.x5 }}>
          <Text className="text-center text-text3xl font-outfitBold text-text">{title}</Text>
          <View style={{ height: spacing.x3 }} />
          <Text
            className="text-center text-textBase font-outfitRegular text-textMuted"
            style={{ lineHeight: 17 * 1.5 }}>
            {description}
          </Text>
        </View>
      </View>
    </ScrollView>
  );
}
