import 'package:supabase_flutter/supabase_flutter.dart';

/// `profiles.role` values that route a signed-in account to the merchant
/// dashboard instead of the customer home (issue #232, superseding the
/// standalone `merchant_app` project from issue #132). Matches the exact set
/// from `profiles_role_check` in
/// `supabase/migrations/20260830120000_add_merchant_role_and_store_ownership.sql`
/// (`'customer' | 'merchant' | 'admin'`, default `'customer'`) -- only
/// `merchant` and `admin` land on the merchant dashboard.
const Set<String> kAllowedMerchantRoles = {'merchant', 'admin'};

/// Pure role-gating predicate, kept separate from [MerchantRoleService] so
/// the routing decision itself is unit-testable without a Supabase client:
/// `merchant`/`admin` route to the merchant dashboard, `customer`, any other
/// string, and `null` (no profile row, or the lookup failed) all route to
/// the ordinary customer home.
bool isAuthorizedMerchantRole(String? role) =>
    role != null && kAllowedMerchantRoles.contains(role);

/// Looks up the signed-in user's `profiles.role`, used by [AppRouter] right
/// after a successful sign-in and again on session-restore at app start
/// (issue #232) to decide whether the account lands on the merchant
/// dashboard or the normal customer home. This intentionally does not
/// perform its own sign-in/sign-out -- the main app's own [AuthService]
/// remains the only sign-in flow; this only answers "which home screen".
class MerchantRoleService {
  MerchantRoleService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Returns the current `profiles.role` for [userId], or `null` if no
  /// profile row exists or the lookup fails. A failure is treated the same
  /// as "no role found" by callers (see [isAuthorizedMerchantRole]) rather
  /// than thrown, so a transient network error at sign-in/session-restore
  /// time fails closed into the customer experience instead of blocking
  /// startup or login.
  Future<String?> fetchRole(String userId) async {
    try {
      final row = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      return row?['role'] as String?;
    } on Object {
      return null;
    }
  }

  /// Convenience combining [fetchRole] with [isAuthorizedMerchantRole].
  Future<bool> isMerchantAccount(String userId) async =>
      isAuthorizedMerchantRole(await fetchRole(userId));
}
