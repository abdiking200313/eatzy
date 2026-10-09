/**
 * Ports `flutter_app/test/onboarding_preferences_test.dart`'s
 * `SharedPreferencesOnboardingPreferences` group (issue #15 on the Flutter
 * side, #360 here) against {@link AsyncStorageOnboardingPreferences}, using
 * an in-memory fake `KeyValueStore` -- mirrors the Dart test's
 * `InMemorySharedPreferencesAsync` fake rather than exercising the real
 * native AsyncStorage module.
 */
import { AsyncStorageOnboardingPreferences, ONBOARDING_HAS_SEEN_KEY, type KeyValueStore } from './onboarding-preferences';

function createInMemoryKeyValueStore(initial: Record<string, string> = {}): KeyValueStore {
  const data = new Map(Object.entries(initial));
  return {
    getItem: async (key) => data.get(key) ?? null,
    setItem: async (key, value) => {
      data.set(key, value);
    },
  };
}

describe('AsyncStorageOnboardingPreferences (issue #360)', () => {
  it('a device that has never finished onboarding reports false', async () => {
    const preferences = new AsyncStorageOnboardingPreferences(createInMemoryKeyValueStore());

    expect(await preferences.hasSeenOnboarding()).toBe(false);
  });

  it('marking onboarding seen persists across reads', async () => {
    const preferences = new AsyncStorageOnboardingPreferences(createInMemoryKeyValueStore());

    await preferences.markOnboardingSeen();

    expect(await preferences.hasSeenOnboarding()).toBe(true);
  });

  it('a previously-seen flag from a prior launch reads back true', async () => {
    const preferences = new AsyncStorageOnboardingPreferences(
      createInMemoryKeyValueStore({ [ONBOARDING_HAS_SEEN_KEY]: 'true' }),
    );

    expect(await preferences.hasSeenOnboarding()).toBe(true);
  });
});
