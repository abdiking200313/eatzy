import { Tabs } from 'expo-router';

// The persistent bottom-nav shell (issue #358). Mirrors app_router.dart's
// `_shellRoute` (a StatefulShellRoute.indexedStack): four visible tabs
// (Home/Explore/Activity/Profile) plus three hidden branches (food/grocery/
// pharmacy) that are reached via navigation from a service card, not from
// the tab bar itself -- `href: null` keeps them part of this navigator
// (so the tab bar stays mounted while browsing a vertical, issue #67)
// without rendering a tab button for them. The real tab-bar UI (icons,
// labels, native-tabs styling) is a later issue -- see
// src/components/app-tabs.tsx, not wired up here yet.
export default function TabsLayout() {
  return (
    <Tabs>
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
