import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_profile.dart';

abstract interface class ProfileRepository {
  Future<CustomerProfile?> fetchCurrentProfile();

  /// Writes any of [firstName], [lastName], [phone], or [dob] — whichever
  /// are non-null — to the current authenticated user's own `profiles` row
  /// and returns the row as saved. A `null` argument leaves that column
  /// unchanged; this lets callers update a single field at a time (see
  /// `ProfileEditController.updateName`/`updatePhone`/`updateDob`) without
  /// re-sending the others.
  ///
  /// `public.profiles` has row-level security with only a `SELECT` policy —
  /// there is no `UPDATE` policy a direct `.update()` call could satisfy.
  /// Implementations must instead call the `update_own_profile` `security
  /// definer` RPC, which derives the target row from `auth.uid()`
  /// server-side (never from a caller-supplied id, matching
  /// [fetchCurrentProfile]) and re-validates the input, raising on anything
  /// invalid rather than trusting the client. Callers are still expected to
  /// validate before calling for fast, field-specific error messages (see
  /// `ProfileEditController`), but the server check is the real guarantee.
  Future<CustomerProfile> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    DateTime? dob,
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
        .select('id, firstname, lastname, phone, avatar_url, dob')
        .eq('id', profileId)
        .maybeSingle();
    if (row == null) {
      return null;
    }
    return CustomerProfile.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<CustomerProfile> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    DateTime? dob,
  }) async {
    final profileId = _client.auth.currentUser?.id;
    if (profileId == null) {
      throw StateError('Sign in before updating a customer profile.');
    }

    final row = await _client
        .rpc<PostgrestMap>(
          'update_own_profile',
          params: {
            'p_firstname': ?firstName,
            'p_lastname': ?lastName,
            'p_phone': ?phone,
            'p_dob': ?dob?.toIso8601String().split('T').first,
          },
        )
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
