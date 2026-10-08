/// Shared render helper for component tests (issue #349).
///
/// Ports the spirit of `flutter_app/test/helpers/app_scope_test_helpers.dart`'s
/// `pumpWithAppScope` — a one-call "render this widget wrapped in the app's
/// ambient providers" helper, to a sensible RN/TanStack-Query equivalent.
///
/// ## Why only `QueryClientProvider`
///
/// `src/app/_layout.tsx` wraps the whole app in `QueryClientProvider` (issue
/// #347) and `ThemeProvider`/`expo-router`'s own root `<Slot>`. Of those,
/// `QueryClientProvider` is the one a plain component/hook test is likely to
/// need just to *not crash* (any `useQuery`/`useMutation` call throws without
/// one) and is also the one that's safe and cheap to provide generically.
///
/// This deliberately does **not** also wrap tests in a real Expo Router route
/// tree. A component that only calls `useRouter()`/`<Link>`/
/// `useLocalSearchParams()` for navigation doesn't need a real route tree to
/// render — but a test that genuinely exercises *routing behavior* (actual
/// navigation between `src/app/**` screens) should reach for Expo Router's
/// own purpose-built harness instead: `expo-router/testing-library`'s
/// `renderRouter`/`testRouter` (see that package's `testing-library.d.ts`),
/// which builds a real in-memory route tree from `src/app/**` and already
/// re-exports all of `@testing-library/react-native`'s queries/`screen`/etc.
/// Reinventing a lighter router stand-in here would just be a second,
/// divergent mock of the same thing Expo Router already ships and tests
/// against itself.
import type { ReactElement, ReactNode } from 'react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, type RenderOptions, type RenderResult } from '@testing-library/react-native';

/**
 * Builds a `QueryClient` suited to a single test: same `staleTime` as the
 * app's shared `queryClient` (`src/platform/query/query-client.ts`), but with
 * retries disabled. Two deliberate differences from the app's defaults, both
 * about not leaving anything running past the test that produced it:
 *
 * - `retry: false` — the app's defaults retry a failing query twice with
 *   backoff up to 30s, fine for a phone on a flaky network, but it would make
 *   a test asserting an error state either slow or prone to leaking a
 *   pending timer past the test if nothing exhausts it.
 * - `gcTime: 0` — no reason to keep anything cached once a test's queries
 *   have settled; avoids a dangling GC timer outliving the test.
 *
 * `staleTime` is kept at the app's real 60s default (not 0, TanStack Query's
 * own out-of-the-box default) deliberately: at `0`, a query that already has
 * data *in the `QueryClient` you hand `renderWithProviders`* (e.g. via
 * `queryClient.setQueryData(...)` before rendering, to test a component
 * against pre-seeded cache) still refetches in the background on mount,
 * which usually isn't what a test seeding that data meant to exercise, and
 * resolves *after* the test's `render`/`act` has already returned — tripping
 * React's "update not wrapped in act(...)" warning. Each call returns a
 * **new** instance (never the app's shared singleton), so tests never leak
 * cached query state into one another — this is also why `renderWithProviders`
 * below builds one per render rather than importing the shared `queryClient`.
 */
export function createTestQueryClient(): QueryClient {
  return new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 60 * 1000,
        retry: false,
        gcTime: 0,
      },
      mutations: {
        retry: false,
      },
    },
  });
}

export interface RenderWithProvidersOptions extends Omit<RenderOptions, 'wrapper'> {
  /** Supply a pre-built `QueryClient` (e.g. one you've pre-populated via `setQueryData`) instead of a fresh one. */
  queryClient?: QueryClient;
}

export interface RenderWithProvidersResult extends RenderResult {
  /** The `QueryClient` actually used — the one passed in, or the fresh one this call built. */
  queryClient: QueryClient;
}

/**
 * Renders `ui` wrapped in a `QueryClientProvider`, the way `_layout.tsx` does
 * at the root of the real app. Returns everything `render` from
 * `@testing-library/react-native` does, plus the `queryClient` used, so a
 * test can assert against it directly (e.g.
 * `queryClient.getQueryState([...])`) without threading its own instance
 * through just to read it back.
 *
 * `@testing-library/react-native`'s `render` is async (v14+), so this is too
 * — call it with `await`.
 */
export async function renderWithProviders(
  ui: ReactElement,
  { queryClient, ...options }: RenderWithProvidersOptions = {},
): Promise<RenderWithProvidersResult> {
  const client = queryClient ?? createTestQueryClient();

  function Wrapper({ children }: { children: ReactNode }) {
    return <QueryClientProvider client={client}>{children}</QueryClientProvider>;
  }

  const result = await render(ui, { ...options, wrapper: Wrapper });
  return { ...result, queryClient: client };
}
