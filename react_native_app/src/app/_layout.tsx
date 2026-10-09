import { QueryClientProvider } from '@tanstack/react-query';
import { DarkTheme, DefaultTheme, Stack, ThemeProvider } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { useColorScheme } from 'react-native';

import { AnimatedSplashOverlay } from '@/components/animated-icon';
import { queryClient } from '@/platform/query/query-client';
// Side-effecting import: constructs the shared Supabase client and starts
// its AppState-driven auto-refresh (see src/platform/supabase/client.ts).
import '@/platform/supabase/client';

SplashScreen.preventAutoHideAsync();

// Root navigator (issue #358). Mirrors app_router.dart's top-level GoRouter
// `routes` list: the public `(auth)` group, the authenticated `(app)` group
// (bottom-nav shell + standalone protected screens), and the standalone
// `merchant` dashboard. `AppRouter._redirect`'s auth/merchant-role gating is
// ported in a later issue (#359/#360) -- this Stack only establishes the
// route tree skeleton.
export default function RootLayout() {
  const colorScheme = useColorScheme();
  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider value={colorScheme === 'dark' ? DarkTheme : DefaultTheme}>
        <AnimatedSplashOverlay />
        <Stack screenOptions={{ headerShown: false }}>
          <Stack.Screen name="(auth)" />
          <Stack.Screen name="(app)" />
          <Stack.Screen name="merchant" />
        </Stack>
      </ThemeProvider>
    </QueryClientProvider>
  );
}
