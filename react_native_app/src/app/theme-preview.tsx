import { ScrollView, Text } from 'react-native';

import { ThemeTokenGallery } from '@/components/theme-token-gallery';

/**
 * Standalone wrapper around `ThemeTokenGallery` (issue #352). The current
 * root layout (`src/app/_layout.tsx`) always renders the two-tab
 * `AppTabs` navigator and has no outlet for sibling top-level routes, so
 * this screen isn't reachable via in-app navigation yet — that's
 * `rn-logic-agent` territory (`_layout.tsx` is out of scope here). The same
 * gallery is also rendered inline on the Explore tab so it's visually
 * provable today; this file keeps a dedicated route ready for whenever a
 * `<Slot />`/dev-menu entry point exists.
 */
export default function ThemePreviewScreen() {
  return (
    <ScrollView className="flex-1 bg-bg" contentContainerClassName="gap-x6 px-screenX py-x6">
      <Text className="text-text3xl font-outfitBold text-text">Theme tokens</Text>
      <Text className="text-textSm font-outfitRegular text-textMuted">
        Light and dark values from tailwind.config.js / src/theme/tokens.ts.
      </Text>
      <ThemeTokenGallery />
    </ScrollView>
  );
}
