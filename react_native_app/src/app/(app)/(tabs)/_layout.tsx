import { MaterialIcons } from '@expo/vector-icons';
import { Tabs, type BottomTabBarProps } from 'expo-router/js-tabs';
import { useState, type ComponentProps } from 'react';
import { Pressable, Text, View } from 'react-native';

import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { spacing } from '@/theme/tokens';

// The persistent bottom-nav shell (issue #358's router skeleton; this issue,
// #370, is the "real tab-bar UI" #358's own top comment deferred). Mirrors
// `flutter_app/lib/app/main_app_screen.dart`'s `MainAppScreen`: four primary
// destinations (Home/Explore/Activity/Profile), each an icon + label,
// tinted `textMuted`/`primary` for unselected/selected -- no selection-pill
// background (`theme.dart`'s `navigationBarTheme` sets `indicatorColor:
// Colors.transparent`; the Dart widget's own comment: "selected state is
// carried by icon color alone").
//
// `food`/`grocery`/`pharmacy` stay registered as hidden branches (`href:
// null`, unchanged from #358) so they remain part of this same navigator
// (the nav bar stays mounted while browsing a vertical -- issue #67)
// without a tab button of their own. `MainAppTabBar` below ports
// `MainAppScreen`'s `_lastPrimaryIndex` + `_syncLastPrimaryIndex`: while one
// of those hidden branches is the active route, it keeps highlighting
// whichever of the four primary tabs was last active, rather than leaving
// every tab unselected (`state.index` would otherwise point at a route
// absent from `NAV_ITEMS`, matching none of them).
//
// `Tabs`/`BottomTabBarProps` come from `expo-router/js-tabs`, not the
// top-level `expo-router` package -- the latter's re-export is flagged
// `@deprecated Use import { Tabs } from 'expo-router/js-tabs' instead` in
// this SDK (57) version's own type declarations. Both resolve to the exact
// same underlying component; this file just uses the non-deprecated path,
// which also conveniently re-exports `BottomTabBarProps` for the custom
// `tabBar` below (see `node_modules/expo-router/build/layouts/Tabs.d.ts`).
export type NavItemName = 'app' | 'explore' | 'activity' | 'profile';

type NavItem = {
  name: NavItemName;
  label: string;
  // @expo/vector-icons' `MaterialIcons` glyph names. This app's informal
  // convention (see `error-state.tsx`'s `error_outline_rounded` ->
  // `error-outline`) is to strip a trailing `_rounded`/`_outlined` Flutter
  // `Icons.*` suffix and kebab-case what's left: `home_outlined` -> `home`,
  // `explore_outlined` -> `explore`, `receipt_long_outlined` ->
  // `receipt-long`. `Icons.person_outline` has no `_rounded`/`_outlined`
  // suffix to strip, so the whole name is kebab-cased as-is -- which
  // happens to land on a real, distinct glyph (`person-outline`, the
  // outlined-person icon) rather than the filled `person` glyph a blind
  // "strip `_outline` too" reading would wrongly suggest. Confirmed both
  // names exist, and that `person-outline` (not `person`) is the one
  // visually matching `Icons.person_outline`, against this repo's own
  // `node_modules/@expo/vector-icons/build/vendor/react-native-vector-icons/
  // glyphmaps/MaterialIcons.json`.
  icon: ComponentProps<typeof MaterialIcons>['name'];
};

const NAV_ITEMS: readonly NavItem[] = [
  { name: 'app', label: 'Home', icon: 'home' },
  { name: 'explore', label: 'Explore', icon: 'explore' },
  { name: 'activity', label: 'Activity', icon: 'receipt-long' },
  { name: 'profile', label: 'Profile', icon: 'person-outline' },
];

/**
 * Custom `tabBar` for the `Tabs` navigator below. The default tab bar
 * (driven entirely by `state.index`) has no way to keep a primary tab
 * highlighted while a hidden food/grocery/pharmacy branch is active --
 * `state.index` would point at that hidden route, matching nothing in
 * `NAV_ITEMS`, and every rendered button would show unselected. See this
 * file's top comment for how `lastPrimaryIndex` below ports
 * `MainAppScreen`'s own `_lastPrimaryIndex`.
 */
function MainAppTabBar({ state, navigation, insets }: BottomTabBarProps) {
  const colors = useSemanticColors();

  const activeRouteName = state.routes[state.index]?.name;
  const activePrimaryIndex = NAV_ITEMS.findIndex((item) => item.name === activeRouteName);

  // Mirrors `MainAppScreen._syncLastPrimaryIndex`/`_lastPrimaryIndex`:
  // remembers the last primary tab seen, for when a hidden branch is
  // active and `activePrimaryIndex` is -1. `setLastPrimaryIndex` is called
  // directly in the render body (not inside a `useEffect`) -- React's own
  // documented "storing information from previous renders" pattern
  // (https://react.dev/reference/react/useState#storing-information-from-previous-renders).
  // A plain ref would read as simpler, but react-hooks' `refs` rule
  // disallows reading/writing `ref.current` during render; a `useEffect`
  // would work too, but only after an extra, otherwise-unnecessary render
  // (and react-hooks' `set-state-in-effect` rule flags calling `setState`
  // from inside one for exactly that reason).
  const [lastPrimaryIndex, setLastPrimaryIndex] = useState(() => (activePrimaryIndex === -1 ? 0 : activePrimaryIndex));
  if (activePrimaryIndex !== -1 && activePrimaryIndex !== lastPrimaryIndex) {
    setLastPrimaryIndex(activePrimaryIndex);
  }

  const selectedIndex = activePrimaryIndex !== -1 ? activePrimaryIndex : lastPrimaryIndex;

  return (
    <View style={{ backgroundColor: colors.white, borderTopWidth: 1, borderTopColor: colors.border, paddingBottom: insets.bottom }}>
      <View style={{ flexDirection: 'row', height: spacing.navBarContentHeight }}>
        {NAV_ITEMS.map((item, index) => {
          const isFocused = index === selectedIndex;
          const route = state.routes.find((candidate) => candidate.name === item.name);
          const tintColor = isFocused ? colors.primary : colors.textMuted;

          const onPress = () => {
            if (!route) return;
            const event = navigation.emit({ type: 'tabPress', target: route.key, canPreventDefault: true });
            if (!isFocused && !event.defaultPrevented) {
              navigation.navigate(route.name);
            }
          };

          return (
            <Pressable
              key={item.name}
              accessibilityRole="tab"
              accessibilityState={{ selected: isFocused }}
              accessibilityLabel={item.label}
              onPress={onPress}
              style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
              <MaterialIcons name={item.icon} size={24} color={tintColor} />
              <Text
                style={{ marginTop: 2 }}
                className={isFocused ? 'text-textXs font-outfitBold text-primary' : 'text-textXs font-outfitMedium text-textMuted'}>
                {item.label}
              </Text>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

export default function TabsLayout() {
  return (
    <Tabs tabBar={(props) => <MainAppTabBar {...props} />}>
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
