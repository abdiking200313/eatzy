/**
 * Ports `flutter_app/test/onboarding_preferences_test.dart`'s
 * `OnboardingLaunchGate` group (`defaults to false and reflects a manual
 * flip`), plus `startup_gate_test.dart`-style coverage of the load step
 * this store's {@link createOnboardingStore.load} ports from
 * `runStartupSequence` (issue #360): starts unresolved, resolves to the
 * persisted flag, and falls back to `false` (not a thrown/failed status)
 * when the persistence layer itself throws.
 */
import { createOnboardingStore, type OnboardingState } from './onboarding-store';
import type { OnboardingPreferences } from '@/platform/startup/onboarding-preferences';

function createFakePreferences(options: {
  hasSeenOnboarding?: boolean;
  hasSeenOnboardingError?: unknown;
} = {}): OnboardingPreferences & { markOnboardingSeenCalls: number } {
  return {
    markOnboardingSeenCalls: 0,
    async hasSeenOnboarding() {
      if (options.hasSeenOnboardingError) {
        throw options.hasSeenOnboardingError;
      }
      return options.hasSeenOnboarding ?? false;
    },
    async markOnboardingSeen() {
      (this as { markOnboardingSeenCalls: number }).markOnboardingSeenCalls += 1;
    },
  };
}

describe('createOnboardingStore', () => {
  it('starts idle with hasSeenOnboarding false before load() is called', () => {
    const { store } = createOnboardingStore({ preferences: createFakePreferences() });

    expect(store.getState()).toMatchObject<Partial<OnboardingState>>({
      status: 'idle',
      hasSeenOnboarding: false,
    });
  });

  it('resolves to the persisted flag once load() finishes', async () => {
    const { store } = createOnboardingStore({
      preferences: createFakePreferences({ hasSeenOnboarding: true }),
    });

    await store.getState().load();

    expect(store.getState()).toMatchObject<Partial<OnboardingState>>({
      status: 'ready',
      hasSeenOnboarding: true,
    });
  });

  it('a device that has never finished onboarding resolves to false', async () => {
    const { store } = createOnboardingStore({ preferences: createFakePreferences() });

    await store.getState().load();

    expect(store.getState()).toMatchObject<Partial<OnboardingState>>({
      status: 'ready',
      hasSeenOnboarding: false,
    });
  });

  it('falls back to false (not a failed status) when the storage read throws', async () => {
    const { store } = createOnboardingStore({
      preferences: createFakePreferences({ hasSeenOnboardingError: new Error('boom') }),
    });

    await store.getState().load();

    expect(store.getState()).toMatchObject<Partial<OnboardingState>>({
      status: 'ready',
      hasSeenOnboarding: false,
    });
  });

  it('load() is a no-op once already loading/loaded', async () => {
    const preferences = createFakePreferences({ hasSeenOnboarding: true });
    const hasSeenOnboardingSpy = jest.spyOn(preferences, 'hasSeenOnboarding');
    const { store } = createOnboardingStore({ preferences });

    await Promise.all([store.getState().load(), store.getState().load()]);
    await store.getState().load();

    expect(hasSeenOnboardingSpy).toHaveBeenCalledTimes(1);
  });

  it('markOnboardingSeen flips the flag synchronously and persists it in the background', async () => {
    const preferences = createFakePreferences();
    const { store } = createOnboardingStore({ preferences });

    store.getState().markOnboardingSeen();

    // Synchronous: no `await` needed to observe the in-memory flip, exactly
    // mirroring `OnboardingLaunchGate.hasSeenOnboarding = true` being set
    // before the Dart `unawaited(...)` persistence call.
    expect(store.getState().hasSeenOnboarding).toBe(true);

    await Promise.resolve();
    expect(preferences.markOnboardingSeenCalls).toBe(1);
  });
});
