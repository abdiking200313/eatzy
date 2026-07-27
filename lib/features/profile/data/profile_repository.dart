import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_profile.dart';

abstract interface class ProfileRepository {
  Future<CustomerProfile?> fetchCurrentProfile();
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
}
