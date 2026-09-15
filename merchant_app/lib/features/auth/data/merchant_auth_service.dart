import 'package:supabase_flutter/supabase_flutter.dart';

/// `profiles.role` values allowed into this app. Matches the exact set from
/// `profiles_role_check` in
/// `supabase/migrations/20260830120000_add_merchant_role_and_store_ownership.sql`
/// on the main repo (`'customer' | 'merchant' | 'admin'`, default
/// `'customer'`) -- only `merchant` and `admin` may use the merchant app.
const Set<String> kAllowedMerchantRoles = {'merchant', 'admin'};

/// Pure role-gating predicate, factored out of [MerchantAuthService] so the
/// access decision itself is unit-testable without a Supabase client:
/// `merchant`/`admin` are allowed in, `customer`, any other string, and
/// `null` (no profile row) are all rejected.
bool isAuthorizedMerchantRole(String? role) =>
    role != null && kAllowedMerchantRoles.contains(role);

/// Raised when a sign-in succeeds against Supabase auth but the resulting
/// account's `profiles.role` is not in [kAllowedMerchantRoles] (e.g. a
/// `customer` account). The caller is expected to have already been signed
/// back out by the time this is thrown -- see
/// [MerchantAuthService.signInWithEmailPassword].
class NotAMerchantException implements Exception {
  const NotAMerchantException(this.role);

  /// The role that was found on the profile (or `null` if no profile row
  /// existed for this user), for diagnostics/messaging.
  final String? role;

  @override
  String toString() =>
      'NotAMerchantException(role: $role): this account is not a merchant '
      'or admin account.';
}

/// Sign-in for the merchant app: authenticates with Supabase auth exactly
/// like the customer app's `AuthService.signInWithEmailPassword` (issue
/// #132), then additionally gates access on `profiles.role`. A successful
/// [SupabaseClient.auth] sign-in for a `customer` (or any other
/// non-merchant) role is immediately signed back out and rejected -- a
/// customer-role account must never reach the merchant shell.
class MerchantAuthService {
  MerchantAuthService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Signs in with email/password, then checks `profiles.role` for the
  /// signed-in user.
  ///
  /// - On success (role is `merchant` or `admin`), returns the session's
  ///   [User].
  /// - On a customer/unknown role, signs the session back out and throws
  ///   [NotAMerchantException].
  /// - On bad credentials or a network error, the underlying
  ///   [AuthException] (or other error) from `signInWithPassword` /
  ///   the profile query propagates unchanged.
  Future<User> signInWithEmailPassword(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException('Sign-in did not return a user.');
    }

    final String? role;
    try {
      role = await _fetchRole(user.id);
    } catch (_) {
      // Fail closed: if we can't verify the role, don't grant access, but
      // still sign the session out to leave no half-authenticated state.
      await _supabase.auth.signOut();
      rethrow;
    }

    if (!isAuthorizedMerchantRole(role)) {
      await _supabase.auth.signOut();
      throw NotAMerchantException(role);
    }

    return user;
  }

  Future<String?> _fetchRole(String userId) async {
    final row = await _supabase
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    return row?['role'] as String?;
  }

  Future<void> signOut() => _supabase.auth.signOut();

  /// The current session's user, if any (does not re-check role).
  User? get currentUser => _supabase.auth.currentUser;

  /// Re-validates an already-persisted session (e.g. after an app restart,
  /// since `supabase_flutter` restores sessions from local storage
  /// automatically) against [kAllowedMerchantRoles].
  ///
  /// Sign-in-time gating in [signInWithEmailPassword] is not enough on its
  /// own: without this check, a session created once as a merchant and
  /// later demoted (or restored on a device after a session was persisted)
  /// could reach the shell without a fresh role check. Returns the [User]
  /// if the current session is still authorized, or `null` if there is no
  /// session or it is no longer authorized (in which case it is signed
  /// out).
  Future<User?> restoreSessionIfAuthorized() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    String? role;
    try {
      role = await _fetchRole(user.id);
    } catch (_) {
      // Network/error while re-validating: treat as unauthorized for this
      // check rather than silently trusting a stale session.
      await _supabase.auth.signOut();
      return null;
    }

    if (!isAuthorizedMerchantRole(role)) {
      await _supabase.auth.signOut();
      return null;
    }
    return user;
  }
}
