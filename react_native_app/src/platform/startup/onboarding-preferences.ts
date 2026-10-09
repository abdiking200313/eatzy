/**
 * Ports `flutter_app/lib/features/onboarding/data/onboarding_preferences.dart`
 * (issue #360).
 *
 * Persists whether this device has already completed or skipped the
 * first-launch welcome/onboarding flow, so a returning signed-out user is
 * not shown it again on a later launch -- read by `onboarding-store.ts`
 * (this app's RN equivalent of Flutter's in-memory `OnboardingLaunchGate`)
 * and, through it, `resolveRedirect`'s `hasSeenOnboarding` parameter.
 *
 * ## Why AsyncStorage, not `expo-secure-store`
 *
 * This single boolean flag is not sensitive the way the Supabase session
 * is (see `secure-session-storage.ts`'s doc comment on why *that* data is
 * encrypted): it carries no credentials and reveals nothing about the user
 * beyond "has opened this app before". Flutter's own
 * `SharedPreferencesOnboardingPreferences` stores it in plain
 * `SharedPreferencesAsync` for the same reason -- plain OS-level key/value
 * storage, not the Keychain/Keystore. `@react-native-async-storage/
 * async-storage` is the direct RN analogue of that: unencrypted,
 * local-only, no practical size limit for a single boolean. There is no
 * cross-platform storage sharing between this app and the Flutter app (they
 * are separate installs with separate storage sandboxes); the only thing
 * mirrored from Flutter here is the *key name* and *semantics*, in case a
 * future shared-storage concern ever needs to recognize the same flag.
 */
import AsyncStorage from '@react-native-async-storage/async-storage';

/** Mirrors `SharedPreferencesOnboardingPreferences._hasSeenOnboardingKey`. */
export const ONBOARDING_HAS_SEEN_KEY = 'onboarding.hasSeenOnboarding';

/** Ports `OnboardingPreferences` (the abstract Dart class). */
export interface OnboardingPreferences {
  hasSeenOnboarding(): Promise<boolean>;
  markOnboardingSeen(): Promise<void>;
}

/**
 * The slice of `@react-native-async-storage/async-storage`'s API this
 * module depends on, narrowed the same way `secure-session-storage.ts`
 * narrows its own storage dependencies -- lets a test inject an in-memory
 * fake instead of the real native module.
 */
export interface KeyValueStore {
  getItem(key: string): Promise<string | null>;
  setItem(key: string, value: string): Promise<void>;
}

const defaultKeyValueStore: KeyValueStore = {
  getItem: (key) => AsyncStorage.getItem(key),
  setItem: (key, value) => AsyncStorage.setItem(key, value),
};

/**
 * Ports `SharedPreferencesOnboardingPreferences`. Stores the flag as the
 * literal string `'true'`/`'false'` (AsyncStorage only stores strings);
 * anything else stored under the key (including nothing at all, for a
 * device that has never finished onboarding) reads back as `false`,
 * mirroring `SharedPreferencesAsync.getBool(...) ?? false`.
 */
export class AsyncStorageOnboardingPreferences implements OnboardingPreferences {
  private readonly store: KeyValueStore;

  constructor(store: KeyValueStore = defaultKeyValueStore) {
    this.store = store;
  }

  async hasSeenOnboarding(): Promise<boolean> {
    return (await this.store.getItem(ONBOARDING_HAS_SEEN_KEY)) === 'true';
  }

  async markOnboardingSeen(): Promise<void> {
    await this.store.setItem(ONBOARDING_HAS_SEEN_KEY, 'true');
  }
}
