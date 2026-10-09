import { QueryClientProvider } from '@tanstack/react-query';
import { DarkTheme, DefaultTheme, Stack, ThemeProvider } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { useColorScheme } from 'react-native';

import { AnimatedSplashOverlay } from '@/components/animated-icon';
import { configureErrorReporting } from '@/platform/error-reporting/configure-error-reporting';
import { ErrorBoundary } from '@/platform/error-reporting/error-boundary';
import { queryClient } from '@/platform/query/query-client';
import { useStartupGate } from '@/platform/startup/use-startup-gate';
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
// ported by #359/#360 (see `(auth)/_layout.tsx`/`(app)/_layout.tsx`) -- this
// Stack only establishes the route tree skeleton.
//
// The `Stack` (and so `(auth)`/`(app)`'s own redirect logic) always mounts
// immediately, regardless of startup-gate status -- `(auth)/_layout.tsx`'s
// own doc comment explains why it renders unguarded while the session
// status is still `'loading'` rather than this component blocking that
// render. What *is* gated on `useStartupGate`'s status (issue #360) is
// `AnimatedSplashOverlay`: it is the thing that actually dismisses the
// native splash screen (`SplashScreen.hideAsync()`, called from its own
// `onLayout`), so holding its mount until both session-restore and
// onboarding-seen state are known keeps the native splash covering
// whatever the Stack is doing underneath (an unguarded render, a redirect)
// until it's safe to reveal -- i.e. a cold start never flashes the wrong
// screen.
export default function RootLayout() {
  const colorScheme = useColorScheme();
  const { status } = useStartupGate();

  return (
    <ErrorBoundary>
      <QueryClientProvider client={queryClient}>
        <ThemeProvider value={colorScheme === 'dark' ? DarkTheme : DefaultTheme}>
          {status === 'ready' && <AnimatedSplashOverlay />}
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
