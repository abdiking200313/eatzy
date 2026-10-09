import { MaterialIcons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useRef, useState } from 'react';
import type { NativeScrollEvent, NativeSyntheticEvent } from 'react-native';
import { Pressable, ScrollView, Text, useWindowDimensions, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { GradientActionButton } from '@/components/gradient-action-button';
import { OnboardingPage1 } from '@/components/onboarding-page-1';
import { OnboardingPage2 } from '@/components/onboarding-page-2';
import { OnboardingPage3 } from '@/components/onboarding-page-3';
import { ZivoLogo } from '@/components/zivo-logo';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { AppRoutes } from '@/platform/navigation/app-routes';
import { useOnboardingStore } from '@/stores/onboarding-store';
import { radius, spacing } from '@/theme/tokens';

// Ports flutter_app/lib/features/onboarding/presentation/welcome_screen.dart's
// `WelcomeScreen`: a 3-slide pager (onboarding_page_1/2/3.dart) under a
// transparent app bar (Zivo logo + "Skip") and a pinned footer (page dots,
// "Get Started", "Already have an account? Log In"). Also opened as
// '/welcome?revisit=true' (AppRoutes.welcomeRevisit) when a returning
// signed-out user backs into onboarding on purpose (see
// `src/app/(auth)/_layout.tsx`'s redirect gate) — same screen either way,
// nothing extra to render for that case.
//
// React Native has no built-in `PageView` equivalent. This uses a plain
// horizontal `ScrollView` with `pagingEnabled`, tracking the active page from
// its scroll offset — the lightest option that needs no new dependency (see
// package.json: no carousel/pager library is installed).
const PAGES = [OnboardingPage1, OnboardingPage2, OnboardingPage3];

export default function WelcomeScreen() {
  const colors = useSemanticColors();
  const { width } = useWindowDimensions();
  const [currentPage, setCurrentPage] = useState(0);
  const scrollRef = useRef<ScrollView>(null);

  const updateCurrentPage = (event: NativeSyntheticEvent<NativeScrollEvent>) => {
    if (width <= 0) {
      return;
    }
    const page = Math.round(event.nativeEvent.contentOffset.x / width);
    setCurrentPage((previous) => (previous === page ? previous : page));
  };

  // Any way out of this screen — skipping, starting registration, or
  // logging in — counts as "seen onboarding": a returning signed-out user
  // should never be shown this sequence again. Mirrors
  // `WelcomeScreen._markOnboardingSeen`: flips the store's in-memory flag
  // synchronously (so re-visiting `/welcome` within this session doesn't
  // re-show it unless explicitly revisited) and persists it in the
  // background via `markOnboardingSeen`.
  const markOnboardingSeen = () => useOnboardingStore.getState().markOnboardingSeen();

  const handleSkip = () => {
    markOnboardingSeen();
    // Mirrors `context.go(AppRoutes.mainApp)`: a terminal exit from
    // onboarding, replacing this screen rather than leaving it on the
    // back-stack.
    router.replace(AppRoutes.mainApp);
  };

  const handleGetStarted = () => {
    markOnboardingSeen();
    // Mirrors `context.push(AppRoutes.register)`: pushes on top of welcome,
    // so the back-stack still leads back to the onboarding slides (see
    // flutter_app/test/auth_back_to_onboarding_test.dart).
    router.push(AppRoutes.register);
  };

  const handleLogIn = () => {
    markOnboardingSeen();
    // Mirrors `context.push(AppRoutes.login)` — same back-stack behavior as
    // "Get Started" above.
    router.push(AppRoutes.login);
  };

  return (
    <View className="flex-1 bg-bg">
      <ScrollView
        ref={scrollRef}
        testID="welcome-pager"
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onScroll={updateCurrentPage}
        onMomentumScrollEnd={updateCurrentPage}
        scrollEventThrottle={16}>
        {PAGES.map((Page, index) => (
          <View key={index} style={{ width }}>
            <Page />
          </View>
        ))}
      </ScrollView>

      <SafeAreaView edges={['top']} pointerEvents="box-none" className="absolute inset-x-0 top-0">
        <View
          pointerEvents="box-none"
          style={{ height: 56, paddingLeft: spacing.x5, paddingRight: spacing.x5 }}
          className="flex-row items-center justify-between">
          <ZivoLogo height={34} />
          <Pressable accessibilityRole="button" onPress={handleSkip} className="active:opacity-70">
            <Text className="text-fontBoldSm font-outfitSemiBold text-primary">Skip</Text>
          </Pressable>
        </View>
      </SafeAreaView>

      <SafeAreaView edges={['bottom']} pointerEvents="box-none" className="absolute inset-x-0 bottom-0">
        <View pointerEvents="box-none" style={{ padding: spacing.x5 }}>
          <View pointerEvents="none" className="flex-row items-center justify-center">
            {PAGES.map((_, index) => (
              <View
                key={index}
                testID={`onboarding-dot-${index}`}
                style={{
                  width: index === currentPage ? 32 : 8,
                  height: 8,
                  marginHorizontal: spacing.x2,
                  borderRadius: radius.full,
                  backgroundColor: index === currentPage ? colors.primary : colors.borderStrong,
                }}
              />
            ))}
          </View>
          <View style={{ height: spacing.x8 }} />
          <GradientActionButton
            label="Get Started"
            onPress={handleGetStarted}
            icon={<MaterialIcons name="arrow-forward" size={20} color={colors.onPrimary} />}
            fontSize={18}
          />
          <View style={{ height: spacing.x5 }} />
          <View className="flex-row items-center justify-center">
            <Text className="text-textXs font-outfitMedium text-textMuted">Already have an account? </Text>
            <Pressable accessibilityRole="button" onPress={handleLogIn}>
              <Text className="text-link font-outfitSemiBold text-primary">Log In</Text>
            </Pressable>
          </View>
        </View>
      </SafeAreaView>
    </View>
  );
}
