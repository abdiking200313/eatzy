/**
 * Ports the "what does the very first redirect need to already know"
 * half of `flutter_app/lib/platform/startup/startup_gate.dart`'s
 * `runStartupSequence` (issue #360): combines session-restore state
 * (#359's session store) and onboarding-seen state (`onboarding-store.ts`)
 * into one `status`, read by the root `_layout.tsx` to decide when it's
 * safe to let `AnimatedSplashOverlay` dismiss the native splash screen,
 * and by `(auth)/_layout.tsx` to supply `resolveRedirect`'s real
 * `hasSeenOnboarding` value instead of the hard-coded `false` left by #359.
 *
 * ## What this does *not* port, and why
 *
 * `runStartupSequence` also runs several steps with no RN equivalent at
 * this layer: `Supabase.initialize` (this app's Supabase client is
 * constructed synchronously, at module load, by `src/platform/supabase/
 * client.ts` -- issue #346 -- well before any gate could run), the
 * food/grocery/pharmacy cart loads and activity load (no RN cart/activity
 * ports exist yet), push notifications, and Crashlytics configuration
 * (already wired unconditionally at root-layout module load by
 * `configure-error-reporting.ts`, issue #351). None of those block this
 * app's first redirect the way session-restore and onboarding-seen state
 * do, so none of them belong in this gate.
 *
 * This also means `status` here only ever reaches `'loading'` or
 * `'ready'`, never a Flutter-`StartupGate`-style failed/retryable status:
 * the one async step this gate actually waits on --
 * `onboarding-store.ts`'s `load()` -- is deliberately best-effort (see its
 * own top comment), matching `runStartupSequence`'s own
 * `_runBestEffort('OnboardingLaunchGate.hasSeenOnboarding', ...)`, which
 * falls back to `false` on failure rather than blocking or failing
 * startup. The one Flutter step that *is* allowed to fail the whole gate
 * (`Supabase.initialize`, covered by `startup_gate_test.dart`'s
 * loading/retry cases) has no equivalent here for the reason above, so
 * there is nothing left in this app's startup path for a retry screen to
 * retry.
 */
import { useEffect } from 'react';

import { useSessionStore } from '@/stores/session-store';
import { useOnboardingStore } from '@/stores/onboarding-store';

export type StartupGateStatus = 'loading' | 'ready';

export interface StartupGateState {
  /**
   * `'loading'` until both the session store has resolved past its own
   * initial `'loading'` status *and* the onboarding store has finished
   * (successfully or not -- see this file's top comment) loading the
   * persisted onboarding-seen flag.
   */
  status: StartupGateStatus;
  isLoggedIn: boolean;
  /** Real value for `resolveRedirect`'s `hasSeenOnboarding` parameter -- `false` while `status === 'loading'`. */
  hasSeenOnboarding: boolean;
}

/**
 * Starts the onboarding-store load (once) and reports the combined
 * session/onboarding readiness. Call this once, from the root `_layout.tsx`
 * -- every other `_layout.tsx` reads the same app-wide stores directly for
 * the `hasSeenOnboarding` value, rather than calling this hook again.
 */
export function useStartupGate(): StartupGateState {
  const sessionStatus = useSessionStore((state) => state.status);
  const userId = useSessionStore((state) => state.userId);
  const onboardingStatus = useOnboardingStore((state) => state.status);
  const hasSeenOnboarding = useOnboardingStore((state) => state.hasSeenOnboarding);
  const load = useOnboardingStore((state) => state.load);

  useEffect(() => {
    void load();
  }, [load]);

  const status: StartupGateStatus =
    sessionStatus === 'loading' || onboardingStatus !== 'ready' ? 'loading' : 'ready';

  return {
    status,
    isLoggedIn: userId != null,
    // Already `false` until the onboarding store's `load()` resolves, so no
    // extra `status === 'ready'` gating is needed here.
    hasSeenOnboarding,
  };
}
