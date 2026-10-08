/// `renderWithProviders` — the component-test entry point for this app
/// (issue #349), playing the same role `app_scope_test_helpers.dart`'s
/// `pumpWithAppScope` plays on the Flutter side: a one-call helper that
/// wraps a component with the provider(s) most components need, so
/// individual tests don't each hand-roll the same wrapper tree, and returns
/// the test-double state the caller might want to assert against.
///
/// ## What this wraps, and what it doesn't
///
/// This always wraps with `QueryClientProvider` — `@tanstack/react-query`'s
/// hooks (`useQuery`/`useMutation`) throw without one, and most screens will
/// eventually use one of those for data loading, so this is the one
/// cross-cutting dependency "almost every component test" needs. By
/// default it builds a fresh `QueryClient` with retries disabled (`retry:
/// false`), unlike the app's real `queryClient`
/// (`src/platform/query/query-client.ts`, which retries twice with
/// backoff) — a failing query in a test should fail (or settle) immediately
/// instead of a test waiting through real retry backoff delays. Pass your
/// own `queryClient` to override this, e.g. to pre-seed cache entries with
/// `queryClient.setQueryData(...)` before rendering.
///
/// It does **not** wrap Expo Router's navigation context (no
/// `NavigationContainer`/route tree). A component that calls `useRouter()`,
/// renders `<Link>`, or reads `useLocalSearchParams()` needs an actual
/// route tree underneath it to resolve against — that's what Expo Router's
/// own `renderRouter` (from `expo-router/testing-library`) is for; reach for
/// that directly for a screen-level test instead of adding a thin, likely
/// wrong, hand-rolled router stub here. (`renderRouter` renders real
/// `src/app/**` routes and accepts the same `options` second argument
/// `@testing-library/react-native`'s own `render` does, so a test needing
/// both router and query context can still pass a `queryClient`-wrapped
/// screen through it.) If a later issue finds most component tests do need
/// some other provider everywhere, add it here the same way `queryClient`
/// is added below, rather than in each test.
import type { ReactElement, ReactNode } from 'react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, type RenderOptions, type RenderResult } from '@testing-library/react-native';

/** A `QueryClient` tuned for tests: no retries, so a failing/pending query settles immediately. */
export function createTestQueryClient(): QueryClient {
  return new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  });
}

export interface RenderWithProvidersOptions extends Omit<RenderOptions, 'wrapper'> {
  /** Overrides the `QueryClient` the component is rendered with (default: a fresh {@link createTestQueryClient}). */
  queryClient?: QueryClient;
}

export interface RenderWithProvidersResult extends RenderResult {
  /** The `QueryClient` actually used, so the caller can assert cache state or seed it further. */
  queryClient: QueryClient;
}

/**
 * Renders `ui` wrapped in a `QueryClientProvider` (see this file's top
 * comment for what is and isn't included), returning everything
 * `@testing-library/react-native`'s own `render` returns plus the
 * `queryClient` used.
 *
 * `@testing-library/react-native`'s `render` is itself async as of v14 (it
 * awaits React's `act()` around the initial render), so this is too —
 * `await` it the same way you would the library's own `render`.
 */
export async function renderWithProviders(
  ui: ReactElement,
  { queryClient = createTestQueryClient(), ...options }: RenderWithProvidersOptions = {},
): Promise<RenderWithProvidersResult> {
  function Wrapper({ children }: { children: ReactNode }) {
    return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>;
  }

  const result = await render(ui, { ...options, wrapper: Wrapper });
  return { ...result, queryClient };
}
