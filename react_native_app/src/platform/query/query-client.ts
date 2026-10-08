/// The shared TanStack Query client (issue #347).
///
/// One `QueryClient` instance for the whole app, provided once at the root
/// (`src/app/_layout.tsx`) via `QueryClientProvider`. Every feature's data
/// hooks should use this client (via `useQuery`/`useMutation` etc.) rather
/// than creating their own, so caching, retries, and refetch behavior stay
/// consistent app-wide.
import { QueryClient } from '@tanstack/react-query';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // Data is treated as fresh for a minute before a mount/refetch will
      // trigger a background refetch — avoids refetching on every screen
      // focus for data that doesn't change that often, while still staying
      // reasonably current. Individual queries can override this.
      staleTime: 60 * 1000,
      // Two retries (three attempts total) with exponential backoff, capped
      // at 30s, instead of the default unlimited-looking (but still
      // eventually-capped) backoff — avoids hammering a down backend from a
      // phone on a flaky connection while still smoothing over one-off
      // network blips.
      retry: 2,
      retryDelay: (attemptIndex: number) => Math.min(1000 * 2 ** attemptIndex, 30 * 1000),
    },
    mutations: {
      // Mutations default to no retry: a mutation is rarely safe to blindly
      // retry (e.g. it may not be idempotent), so an explicit opt-in per
      // mutation is safer than a blanket default.
      retry: 0,
    },
  },
});
