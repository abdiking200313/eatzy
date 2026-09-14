import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether this device has already completed or skipped the
/// first-launch welcome/onboarding flow (see `WelcomeScreen`), so a
/// returning signed-out user is not shown it again on a later launch
/// (issue #15).
abstract class OnboardingPreferences {
  Future<bool> hasSeenOnboarding();

  Future<void> markOnboardingSeen();
}

/// A [OnboardingPreferences] backed by `SharedPreferencesAsync`, mirroring
/// the storage pattern `SharedPreferencesCartStorage` already uses
/// elsewhere in the app (see `services/shared/data/cart_storage.dart`).
class SharedPreferencesOnboardingPreferences implements OnboardingPreferences {
  const SharedPreferencesOnboardingPreferences();

  static const _hasSeenOnboardingKey = 'onboarding.hasSeenOnboarding';

  SharedPreferencesAsync get _preferences => SharedPreferencesAsync();

  @override
  Future<bool> hasSeenOnboarding() async {
    return await _preferences.getBool(_hasSeenOnboardingKey) ?? false;
  }

  @override
  Future<void> markOnboardingSeen() {
    return _preferences.setBool(_hasSeenOnboardingKey, true);
  }
}

/// An in-memory cache of [OnboardingPreferences.hasSeenOnboarding], so
/// `AppRouter`'s synchronous redirect logic can consult it on every
/// navigation without an async SharedPreferences read. Populated once at
/// startup from [SharedPreferencesOnboardingPreferences] (see `main.dart`)
/// and flipped to `true` the moment a signed-out user finishes or skips the
/// welcome/onboarding flow (see `WelcomeScreen`), so a later in-session
/// navigation back to `/welcome` (e.g. an OS back gesture) is gated
/// immediately too, not just after the next app launch.
class OnboardingLaunchGate {
  OnboardingLaunchGate._();

  static bool hasSeenOnboarding = false;
}
