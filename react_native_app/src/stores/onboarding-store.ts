/**
 * Ports Flutter's `OnboardingLaunchGate` (in
 * `flutter_app/lib/features/onboarding/data/onboarding_preferences.dart`)
 * plus the one `runStartupSequence` step that populates it (issue #360).
 *
 * Flutter keeps `OnboardingLaunchGate.hasSeenOnboarding` as a plain static
 * bool so `AppRouter`'s synchronous redirect can read it on every
 * navigation without an async storage read, loading it once at startup
 * (`main.dart` -> `runStartupSequence`) and flipping it to `true` in-memory
 * the moment a signed-out user finishes/skips the welcome screen (see
 * `welcome_screen.dart`'s `_markOnboardingSeen`), persisting the real write
 * in the background (`unawaited(...)`) rather than blocking on it. This
 * Zustand store is the same shape: `status`/`hasSeenOnboarding` are read
 * synchronously by `use-startup-gate.ts` and `(auth)/_layout.tsx`'s
 * `resolveRedirect` call, {@link load} is this app's `runStartupSequence`
 * step (called once, from `use-startup-gate.ts`), and
 * {@link markOnboardingSeen} is what a future welcome-screen build (not
 * this issue's scope -- `src/app/(auth)/welcome.tsx` is still a placeholder)
 * should call on "Get started"/"Skip": it updates `hasSeenOnboarding`
 * synchronously and persists in the background, exactly mirroring
 * `_markOnboardingSeen`.
 *
 * {@link load}'s failure handling mirrors `runStartupSequence`'s
 * `_runBestEffort('OnboardingLaunchGate.hasSeenOnboarding', ...)` call:
 * a storage read failure reports the error and falls back to `false` (show
 * onboarding) rather than blocking startup or surfacing a retry UI -- see
 * `use-startup-gate.ts`'s top comment for why that means this store's
 * `status` only ever reaches `'ready'`, never a failed/retryable state.
 */
import { create, type StoreApi, type UseBoundStore } from 'zustand';

import { ErrorReporting } from '@/platform/error-reporting/error-reporter';
import {
  AsyncStorageOnboardingPreferences,
  type OnboardingPreferences,
} from '@/platform/startup/onboarding-preferences';

export type OnboardingLoadStatus = 'idle' | 'loading' | 'ready';

export interface OnboardingState {
  /** `'idle'` until {@link OnboardingState.load} is called, then `'loading'` until the stored flag (or the best-effort `false` fallback) resolves. */
  status: OnboardingLoadStatus;
  /** Mirrors `OnboardingLaunchGate.hasSeenOnboarding`. `false` until {@link load} resolves. */
  hasSeenOnboarding: boolean;
  /** Ports the `OnboardingLaunchGate.hasSeenOnboarding` load step in `runStartupSequence`. Safe to call more than once -- every call after the first no-ops while already loading/loaded. */
  load: () => Promise<void>;
  /** Ports `WelcomeScreen._markOnboardingSeen`. */
  markOnboardingSeen: () => void;
}

export interface CreateOnboardingStoreOptions {
  preferences?: OnboardingPreferences;
}

export interface OnboardingStoreHandle {
  store: UseBoundStore<StoreApi<OnboardingState>>;
}

/**
 * Builds an independent onboarding store wired to `options.preferences`
 * (a real {@link AsyncStorageOnboardingPreferences} by default). Exists
 * mainly so a test can build an isolated instance with a fake preferences
 * implementation instead of sharing the app-wide singleton -- see
 * {@link useOnboardingStore} for the one the app actually renders against.
 */
export function createOnboardingStore(
  options: CreateOnboardingStoreOptions = {},
): OnboardingStoreHandle {
  const preferences = options.preferences ?? new AsyncStorageOnboardingPreferences();

  const store = create<OnboardingState>((set, get) => ({
    status: 'idle',
    hasSeenOnboarding: false,
    load: async () => {
      if (get().status !== 'idle') {
        return;
      }
      set({ status: 'loading' });

      let hasSeenOnboarding = false;
      try {
        hasSeenOnboarding = await preferences.hasSeenOnboarding();
      } catch (error) {
        ErrorReporting.instance.reportError(
          error,
          error instanceof Error ? error.stack : undefined,
          'OnboardingStore.load',
        );
      }
      set({ status: 'ready', hasSeenOnboarding });
    },
    markOnboardingSeen: () => {
      set({ hasSeenOnboarding: true });
      preferences.markOnboardingSeen().catch((error: unknown) => {
        ErrorReporting.instance.reportError(
          error,
          error instanceof Error ? error.stack : undefined,
          'OnboardingStore.markOnboardingSeen',
        );
      });
    },
  }));

  return { store };
}

const defaultOnboardingStore = createOnboardingStore();

/**
 * The app-wide onboarding store. Read it the way any Zustand store is read,
 * e.g. `useOnboardingStore((state) => state.hasSeenOnboarding)`.
 */
export const useOnboardingStore = defaultOnboardingStore.store;
