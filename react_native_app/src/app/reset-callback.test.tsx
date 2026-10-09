/**
 * Confirms `/reset-callback` is a real, matched route (issue #361) --
 * the part of the acceptance criteria ("a password-reset link opens the
 * reset screen with a valid session") this sandbox can exercise without a
 * real device: Expo Router's own native deep-link handling strips the
 * `zivo://` scheme from `zivo://reset-callback#access_token=...` down to
 * the path `reset-callback` itself (see `use-password-recovery-redirect.
 * ts`'s top comment for the exact mechanism, verified by reading
 * `node_modules/expo-router/build/fork/extractPathFromURL.js`), so what
 * matters here is that path resolving to a real screen rather than
 * `+not-found`. This test drives that from the resolved in-app path
 * (`/reset-callback`) rather than the literal `zivo://` URL, the same way
 * `route-reachability.test.tsx` (#358) exercises every other route.
 *
 * The actual "starts the session, then replaces itself with
 * `/reset-password`" behavior is `use-password-recovery-redirect.test.ts`'s
 * job, exercised against the hook directly via a plain `renderHook` rather
 * than a full `renderRouter` tree: driving a real cross-group `router.
 * replace()` through this sandbox's React Navigation test environment
 * (no real native `Linking`/timers) hangs rather than settling, which is
 * exactly the kind of real-device-only behavior the issue anticipated this
 * sandbox couldn't fully exercise.
 */
import { renderRouter } from 'expo-router/testing-library';

jest.mock('@/components/animated-icon', () => ({ AnimatedSplashOverlay: () => null }));
jest.mock('@/platform/supabase/client', () => ({
  supabase: {
    auth: {
      onAuthStateChange: () => ({ data: { subscription: { unsubscribe: () => {} } } }),
      setSession: () => Promise.resolve(),
    },
  },
}));
// See `route-reachability.test.tsx`'s top comment for why
// `@/platform/query/query-persistence` is mocked too -- this file mounts
// the same real root `_layout.tsx`.
jest.mock('@/platform/query/query-persistence', () => ({
  queryPersistOptions: {
    persister: {
      persistClient: () => {},
      restoreClient: () => Promise.resolve(undefined),
      removeClient: () => Promise.resolve(undefined),
    },
    maxAge: 0,
    dehydrateOptions: { shouldDehydrateQuery: () => false },
  },
}));

// `expo-linking`'s real `useURL()` depends on native modules this sandbox
// doesn't have; it's irrelevant to this file's one assertion (route
// reachability, not what the screen's effect does with the URL), so a
// constant `null` is enough -- the hook then does nothing, same as a cold
// render before any URL event has arrived.
jest.mock('expo-linking', () => ({ useURL: () => null }));

describe('/reset-callback (issue #361)', () => {
  it('resolves to a real screen instead of +not-found', async () => {
    const result = renderRouter('src/app', { initialUrl: '/reset-callback' });
    await result;

    expect(result.getPathname()).toBe('/reset-callback');
  });
});
