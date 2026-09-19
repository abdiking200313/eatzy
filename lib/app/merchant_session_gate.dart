import '../features/merchant/auth/data/merchant_role_service.dart';

/// Caches whether the currently signed-in account should land on the
/// merchant dashboard instead of the customer home (issue #232).
///
/// `AppRouter.resolveRedirect` needs this decision synchronously on every
/// navigation, but the underlying `profiles.role` lookup
/// ([MerchantRoleService.fetchRole]) is async. [resolveFor] does that lookup
/// once per signed-in user and caches the answer here; `AppRouter` awaits it
/// *before* deciding where a freshly signed-in account goes, so a
/// `merchant`/`admin` is never bounced through the customer home while the
/// role is still unknown. Login and session-restore at app start call it
/// too, sharing the same in-flight lookup, mirroring how
/// `OnboardingLaunchGate.hasSeenOnboarding` is loaded once at startup for
/// the same reason (issue #15).
class MerchantSessionGate {
  MerchantSessionGate._();

  /// How long the role lookup may run before the account is treated as a
  /// plain customer (the same fail-closed answer a failed lookup gives).
  static const Duration roleLookupTimeout = Duration(seconds: 15);

  /// Whether the current session's account is `merchant`/`admin`. Defaults
  /// to `false` (customer routing) until [resolveFor] sets it, and is reset
  /// to `false` on sign-out.
  static bool isMerchantRole = false;

  /// Whether the current session's account is specifically `admin` (a
  /// strict subset of [isMerchantRole]), set alongside it. Makes
  /// [MerchantShell] show the "Accounts" role-management list (and nothing
  /// else) -- a plain `merchant` account never sees it. This is only a UI
  /// convenience: the actual authorization is enforced server-side by the
  /// `admin_list_profiles`/`admin_set_profile_role` RPCs, not by this flag.
  static bool isAdmin = false;

  /// The user id [isMerchantRole]/[isAdmin] were resolved for, or `null` if
  /// nothing has been resolved this session. A different signed-in user id
  /// means the cached flags are stale.
  static String? resolvedUserId;

  static String? _inFlightUserId;
  static Future<void>? _inFlight;

  /// Bumped by [reset] so a lookup that was already running when the user
  /// signed out cannot write its result over the cleared state.
  static int _generation = 0;

  /// Looks up [userId]'s `profiles.role` and caches it in [isMerchantRole] /
  /// [isAdmin] / [resolvedUserId]. Returns immediately if that user is
  /// already resolved, and joins an already-running lookup for the same
  /// user rather than starting a second one. A failed or timed-out lookup
  /// resolves to a plain customer, like [MerchantRoleService.fetchRole]
  /// itself.
  static Future<void> resolveFor(
    String userId, {
    MerchantRoleService? roleService,
  }) {
    if (resolvedUserId == userId) return Future.value();
    if (_inFlightUserId == userId && _inFlight != null) return _inFlight!;

    final generation = _generation;
    final lookup = () async {
      final role = await (roleService ?? MerchantRoleService())
          .fetchRole(userId)
          .timeout(roleLookupTimeout, onTimeout: () => null);
      if (generation != _generation) return;
      isMerchantRole = isAuthorizedMerchantRole(role);
      isAdmin = role == 'admin';
      resolvedUserId = userId;
    }();
    _inFlightUserId = userId;
    _inFlight = lookup;
    return lookup.whenComplete(() {
      if (identical(_inFlight, lookup)) {
        _inFlight = null;
        _inFlightUserId = null;
      }
    });
  }

  /// Clears everything on sign-out (or when a startup lookup fails), so the
  /// next sign-in or session-restore starts from a fresh lookup rather than
  /// a stale cached role.
  static void reset() {
    _generation++;
    isMerchantRole = false;
    isAdmin = false;
    resolvedUserId = null;
    _inFlight = null;
    _inFlightUserId = null;
  }
}
