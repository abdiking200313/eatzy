import { QueryClientProvider } from '@tanstack/react-query';
import { DarkTheme, DefaultTheme, Stack, ThemeProvider } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { useColorScheme } from 'react-native';

import { AnimatedSplashOverlay } from '@/components/animated-icon';
import { configureErrorReporting } from '@/platform/error-reporting/configure-error-reporting';
import { ErrorBoundary } from '@/platform/error-reporting/error-boundary';
import { queryClient } from '@/platform/query/query-client';
// Side-effecting import: constructs the shared Supabase client and starts
// its AppState-driven auto-refresh (see src/platform/supabase/client.ts).
import '@/platform/supabase/client';

SplashScreen.preventAutoHideAsync();

// Wires ErrorReporting.instance to Crashlytics (falls back to the default
// LoggingErrorReporter where the native module isn't available, e.g. Expo
// Go) -- see configure-error-reporting.ts (issue #351).
void configureErrorReporting();

// Root navigator (issue #358). Mirrors app_router.dart's top-level GoRouter
// `routes` list: the public `(auth)` group, the authenticated `(app)` group
// (bottom-nav shell + standalone protected screens), and the standalone
// `merchant` dashboard. `AppRouter._redirect`'s auth/merchant-role gating is
// ported in a later issue (#359/#360) -- this Stack only establishes the
// route tree skeleton.
export default function RootLayout() {
  const colorScheme = useColorScheme();
  return (
    <ErrorBoundary>
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
    </ErrorBoundary>
  );
}
