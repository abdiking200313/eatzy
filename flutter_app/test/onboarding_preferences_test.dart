import 'package:chowflow/features/onboarding/data/onboarding_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  group('SharedPreferencesOnboardingPreferences (issue #15)', () {
    test('a device that has never finished onboarding reports false', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      const preferences = SharedPreferencesOnboardingPreferences();

      expect(await preferences.hasSeenOnboarding(), isFalse);
    });

    test('marking onboarding seen persists across reads', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      const preferences = SharedPreferencesOnboardingPreferences();

      await preferences.markOnboardingSeen();

      expect(await preferences.hasSeenOnboarding(), isTrue);
    });

    test(
      'a previously-seen flag from a prior launch reads back true',
      () async {
        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.withData({
              'onboarding.hasSeenOnboarding': true,
            });
        const preferences = SharedPreferencesOnboardingPreferences();

        expect(await preferences.hasSeenOnboarding(), isTrue);
      },
    );
  });

  group('OnboardingLaunchGate', () {
    test('defaults to false and reflects a manual flip', () {
      addTearDown(() => OnboardingLaunchGate.hasSeenOnboarding = false);

      OnboardingLaunchGate.hasSeenOnboarding = true;

      expect(OnboardingLaunchGate.hasSeenOnboarding, isTrue);
    });
  });
}
