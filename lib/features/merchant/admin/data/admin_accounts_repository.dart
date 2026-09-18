import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_account_lookup.dart';

/// Thrown when `admin_lookup_profile_by_email` or `admin_set_profile_role`
/// rejects the call -- caller isn't an admin, no account matches the email,
/// an invalid role, or (per
/// `supabase/migrations/20260921020000_add_admin_role_management_rpcs.sql`)
/// an attempt to demote the last remaining admin. [message] is the RPC's own
/// `raise exception` text, already specific and human-readable, so it is
/// surfaced to the admin verbatim rather than replaced with a generic
/// message.
class AdminAccountsException implements Exception {
  const AdminAccountsException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Data access for the admin-only "promote an account" flow (requested
/// directly by the app owner, 2026-09-18, see the migration above): looking
/// up an account by its sign-up email and changing its `profiles.role`.
/// Both operations are admin-gated server-side -- see the RPCs' own
/// `security definer` checks -- so this repository adds no client-side
/// authorization logic of its own, matching `MerchantStoreRepository`'s
/// doc comment on why: the client should never assume it is allowed to call
/// these just because the screen is reachable.
abstract interface class AdminAccountsRepository {
  /// Looks up the account signed up with [email], or `null` if none
  /// matches. Throws [AdminAccountsException] if the caller is not an
  /// admin.
  Future<AdminAccountLookup?> lookupByEmail(String email);

  /// Sets [profileId]'s `profiles.role` to [newRole] (`'customer'`,
  /// `'merchant'`, or `'admin'`). Throws [AdminAccountsException] on any
  /// rejection (not an admin, invalid role, unknown profile, or would leave
  /// zero admins).
  Future<void> setRole({required String profileId, required String newRole});
}

class SupabaseAdminAccountsRepository implements AdminAccountsRepository {
  // `client` is deliberately a public-looking named parameter, matching
  // every other Supabase-backed repository in this feature (e.g.
  // `SupabaseMerchantStoreRepository`); an initializing formal would force
  // the external name to the private `_client`.
  SupabaseAdminAccountsRepository({required SupabaseClient client})
    // ignore: prefer_initializing_formals
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<AdminAccountLookup?> lookupByEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('An email address is required.');
    }
    try {
      final rows =
          await _client.rpc<Object?>(
                'admin_lookup_profile_by_email',
                params: {'target_email': trimmed},
              )
              as List<dynamic>;
      if (rows.isEmpty) return null;
      return AdminAccountLookup.fromMap(rows.first as Map<String, dynamic>);
    } on PostgrestException catch (error) {
      throw AdminAccountsException(error.message);
    }
  }

  @override
  Future<void> setRole({
    required String profileId,
    required String newRole,
  }) async {
    try {
      await _client.rpc<void>(
        'admin_set_profile_role',
        params: {'target_profile_id': profileId, 'new_role': newRole},
      );
    } on PostgrestException catch (error) {
      throw AdminAccountsException(error.message);
    }
  }
}
