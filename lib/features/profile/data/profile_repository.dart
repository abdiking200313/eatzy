import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_profile.dart';

abstract interface class ProfileRepository {
  Future<CustomerProfile?> fetchCurrentProfile();

  /// Writes [firstName], [lastName], and [phone] to the current
  /// authenticated user's own `profiles` row and returns the row as saved.
  ///
  /// Scoped to the signed-in user only — implementations must derive the
  /// target row from the active session (never from a caller-supplied id),
  /// matching [fetchCurrentProfile] and relying on the same
  /// `"Profiles are editable by owner"` row-level-security policy
  /// (`supabase/schema.sql`) as a second line of defense.
  ///
  /// [phone] may be empty, which is stored as `null` (the column is
  /// nullable); [firstName] and [lastName] must be non-empty since the
  /// column is `not null` — callers are expected to validate before calling
  /// (see `ProfileEditController`).
  Future<CustomerProfile> updateProfile({
    required String firstName,
    required String lastName,
    required String phone,
  });

  /// Permanently deletes (anonymizes) the current authenticated user's own
  /// account via the `delete_own_account` Supabase RPC (issue #36 — App
  /// Store Guideline 5.1.1(v)/Google Play require an in-app deletion path).
  ///
  /// Scoped to the signed-in user only — the RPC is `security definer` and
  /// derives the target row from `auth.uid()` server-side, never from a
  /// caller-supplied id, matching [fetchCurrentProfile] and [updateProfile].
  /// Callers must sign the user out immediately after this succeeds: the
  /// underlying `auth.users` row is not removed (see the migration's
  /// comment for why), only the `profiles` row's PII and the user's other
  /// owned data, so a session left active would keep working against a
  /// wiped profile.
  Future<void> deleteAccount();
}

class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<CustomerProfile?> fetchCurrentProfile() async {
    final profileId = _client.auth.currentUser?.id;
    if (profileId == null) {
      throw StateError('Sign in before loading a customer profile.');
    }

    final row = await _client
        .from('profiles')
        .select('id, firstname, lastname, phone, avatar_url')
        .eq('id', profileId)
        .maybeSingle();
    if (row == null) {
      return null;
    }
    return CustomerProfile.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<CustomerProfile> updateProfile({
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final profileId = _client.auth.currentUser?.id;
    if (profileId == null) {
      throw StateError('Sign in before updating a customer profile.');
    }

    final trimmedPhone = phone.trim();
    final row = await _client
        .from('profiles')
        .update({
          'firstname': firstName.trim(),
          'lastname': lastName.trim(),
          'phone': trimmedPhone.isEmpty ? null : trimmedPhone,
        })
        // Scopes the write to the signed-in user's own row — never trust an
        // id from the caller. RLS ("Profiles are editable by owner") backs
        // this up independently.
        .eq('id', profileId)
        .select('id, firstname, lastname, phone, avatar_url')
        .single();
    return CustomerProfile.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> deleteAccount() async {
    final profileId = _client.auth.currentUser?.id;
    if (profileId == null) {
      throw StateError('Sign in before deleting your account.');
    }

    // No params: the RPC is security definer and scopes itself to
    // auth.uid() server-side, so there is nothing for the client to pass.
    await _client.rpc<void>('delete_own_account');
  }
}
