/// Caches whether the currently signed-in account should land on the
/// merchant dashboard instead of the customer home (issue #232).
///
/// `AppRouter.resolveRedirect` needs this decision synchronously on every
/// navigation, but the underlying `profiles.role` lookup
/// ([MerchantRoleService.fetchRole]) is async -- so the two call sites that
/// actually know the answer (a successful sign-in in `LoginScreen`, and
/// session-restore in `runStartupSequence`) resolve it once and cache it
/// here, mirroring how `OnboardingLaunchGate.hasSeenOnboarding` is loaded
/// once at startup for the same reason (issue #15).
class MerchantSessionGate {
  MerchantSessionGate._();

  /// Whether the current session's account is `merchant`/`admin`. Defaults
  /// to `false` (customer routing) until a sign-in or session-restore check
  /// sets it, and is reset to `false` on sign-out.
  static bool isMerchantRole = false;
}
