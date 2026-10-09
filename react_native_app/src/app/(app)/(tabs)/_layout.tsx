import { MaterialIcons } from '@expo/vector-icons';
import { Tabs } from 'expo-router';
import { useState } from 'react';
import { Pressable, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { useSemanticColors } from '@/hooks/use-semantic-colors';

/**
 * Ports `flutter_app/lib/app/main_app_screen.dart`'s `MainAppScreen`
 * (issue #370) — the persistent bottom-nav shell around Home/Explore/
 * Activity/Profile, plus the hidden food/grocery/pharmacy vertical branches
 * added in issue #358 (kept part of this same navigator via `href: null` so
 * entering one keeps this tab bar on screen, rather than stacking a
 * full-screen route over it, mirroring Flutter's `StatefulShellRoute.
 * indexedStack` branches that aren't bottom-nav destinations of their own).
 *
 * This file only builds the shell: the four tabs' own screen content
 * (`app.tsx`/`explore.tsx`/`activity.tsx`/`profile.tsx`) stays the
 * placeholder from #358 until #373/#374/future activity-feed work give them
 * real content — see each screen file's own doc comment.
 */

/**
 * The four primary bottom-nav destinations, in the exact order, icon, and
 * label `main_app_screen.dart`'s `_navigationItems` uses. Flutter reuses the
 * same (`_outlined`) icon for both the unselected and selected state and
 * only swaps its color (`TwColors.textMuted` vs `TwColors.primary`) — this
 * does the same, one icon per tab, color-toggled on focus.
 *
 * `@expo/vector-icons`'s `MaterialIcons` font (the classic Material Icons
 * glyph set this app already uses everywhere else, see
 * `src/hooks/use-semantic-colors.ts`'s doc comment) has no dedicated
 * "outlined" variant for most of these glyphs the way Flutter's Material
 * Symbols font does (`home_outlined`, `explore_outlined`,
 * `receipt_long_outlined`) — `home`/`explore`/`receipt-long` are its closest
 * available equivalents. `person-outline` is an exact name match for
 * `Icons.person_outline`.
 */
const PRIMARY_TABS = [
  { name: 'app', label: 'Home', icon: 'home' },
  { name: 'explore', label: 'Explore', icon: 'explore' },
  { name: 'activity', label: 'Activity', icon: 'receipt-long' },
  { name: 'profile', label: 'Profile', icon: 'person-outline' },
] as const satisfies readonly {
  name: string;
  label: string;
  icon: keyof typeof MaterialIcons.glyphMap;
}[];

/** Mirrors `MainAppScreen.activityTabIndex`'s route, by name rather than index. */
const ACTIVITY_TAB_NAME = 'activity';

/**
 * No-op stand-in for Flutter's default `ActivityController.instance.load`
 * (see `onActivityTabFocused` below) -- this app has no ported
 * `ActivityController`/activity feed yet (that lands in a later issue), so
 * there is nothing real to reload on focus yet.
 */
function noopActivityReload() {}

/**
 * Minimal structural shape of the `tabBar` render-prop `Tabs` (from
 * `expo-router`, built on `@react-navigation/bottom-tabs`) calls this
 * component with -- typed by hand for just the fields read below instead of
 * importing `BottomTabBarProps` from `@react-navigation/bottom-tabs`: that
 * package isn't a direct dependency of this app (`expo-router` bundles it
 * internally under an unstable `build/react-navigation/bottom-tabs` path
 * that isn't part of its public `exports`).
 */
export type MainTabBarProps = {
  state: {
    index: number;
    routes: readonly { key: string; name: string }[];
  };
  navigation: {
    navigate: (name: string) => void;
  };
  /**
   * Called whenever the bar switches *to* the Activity tab -- not when
   * re-tapping the already-focused Activity tab, and not for any other
   * tab. Mirrors `MainAppScreen.onActivityTabFocused`, including its
   * test-only purpose: production code never overrides this (it defaults
   * to `noopActivityReload` above), but a test can inject its own callback
   * to observe the reload without a real activity store.
   */
  onActivityTabFocused?: () => void | Promise<void>;
};

/**
 * The actual bottom-nav bar, replacing `Tabs`' default one so it can keep
 * highlighting the primary tab the user was last on while a hidden
 * food/grocery/pharmacy branch is active, and so switching to the Activity
 * tab can trigger `onActivityTabFocused` -- neither of which the default
 * tab bar supports. Exported so `_layout.test.tsx` can mount it against a
 * small test-only tab tree, the same way `main_app_screen_test.dart` builds
 * a fresh `GoRouter` + `MainAppScreen` per test rather than exercising the
 * real app's routes.
 */
export function MainTabBar({ state, navigation, onActivityTabFocused }: MainTabBarProps) {
  const colors = useSemanticColors();

  // The food/grocery/pharmacy verticals are additional hidden branches of
  // this same navigator (see this file's top comment) but aren't
  // destinations of their own in this bar. While one of them is active,
  // mirrors `MainAppScreen._lastPrimaryIndex`: keep highlighting whichever
  // of the four primary tabs the user was last on, rather than no selection
  // at all. Recorded (and, below, adjusted) during render rather than in a
  // `useEffect` -- this is React's documented "adjust state while
  // rendering" pattern for deriving state from a prop/value that changed
  // since the last render (https://react.dev/learn/you-might-not-need-an-
  // effect#adjusting-some-state-when-a-prop-changes), which avoids both an
  // extra post-commit render and a dependency on effect ordering.
  const currentRoute = state.routes[state.index];
  const currentPrimaryIndex = PRIMARY_TABS.findIndex((tab) => tab.name === currentRoute?.name);

  const [recordedPrimaryIndex, setRecordedPrimaryIndex] = useState(
    currentPrimaryIndex !== -1 ? currentPrimaryIndex : 0,
  );
  const [prevPrimaryIndex, setPrevPrimaryIndex] = useState(currentPrimaryIndex);
  if (currentPrimaryIndex !== prevPrimaryIndex) {
    setPrevPrimaryIndex(currentPrimaryIndex);
    if (currentPrimaryIndex !== -1) {
      setRecordedPrimaryIndex(currentPrimaryIndex);
    }
  }

  const selectedIndex = currentPrimaryIndex !== -1 ? currentPrimaryIndex : recordedPrimaryIndex;

  return (
    <SafeAreaView edges={['bottom']} style={{ backgroundColor: colors.white }} className="border-t border-border">
      <View className="flex-row">
        {PRIMARY_TABS.map((tab, index) => {
          const route = state.routes.find((candidate) => candidate.name === tab.name);
          const isSelected = index === selectedIndex;
          const color = isSelected ? colors.primary : colors.textMuted;

          return (
            <Pressable
              key={tab.name}
              accessibilityRole="button"
              accessibilityLabel={tab.label}
              accessibilityState={{ selected: isSelected }}
              onPress={() => {
                if (!route) {
                  return;
                }
                const isFocused = route.key === currentRoute?.key;
                const isSwitchingToActivity = tab.name === ACTIVITY_TAB_NAME && !isFocused;
                if (!isFocused) {
                  navigation.navigate(route.name);
                }
                if (isSwitchingToActivity) {
                  void (onActivityTabFocused ?? noopActivityReload)();
                }
              }}
              className="flex-1 items-center justify-center py-x2">
              <MaterialIcons name={tab.icon} size={24} color={color} />
              <Text style={{ color }} className="mt-x1 text-textXs">
                {tab.label}
              </Text>
            </Pressable>
          );
        })}
      </View>
    </SafeAreaView>
  );
}

export default function TabsLayout() {
  return (
    <Tabs
      // Flutter's `MainAppScreen` has no `AppBar` of its own (`Scaffold
      // (body: navigationShell, bottomNavigationBar: ...)`) -- any header a
      // tab needs is that screen's own content to render, not this shell's.
      screenOptions={{ headerShown: false }}
      // See `MainTabBarProps`'s doc comment on why this isn't typed against
      // `@react-navigation/bottom-tabs` directly.
      tabBar={(props: any) => <MainTabBar {...props} />}>
      <Tabs.Screen name="app" options={{ title: 'Home' }} />
      <Tabs.Screen name="explore" options={{ title: 'Explore' }} />
      <Tabs.Screen name="activity" options={{ title: 'Activity' }} />
      <Tabs.Screen name="profile" options={{ title: 'Profile' }} />
      <Tabs.Screen name="food" options={{ title: 'Food', href: null }} />
      <Tabs.Screen name="grocery" options={{ title: 'Grocery', href: null }} />
      <Tabs.Screen name="pharmacy" options={{ title: 'Pharmacy', href: null }} />
    </Tabs>
  );
}
