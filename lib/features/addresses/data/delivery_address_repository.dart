import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/delivery_address.dart';

/// Data access for the shared `public.delivery_addresses` platform table
/// (issue #78). This exists so the data layer for a real saved-addresses
/// feature is in place and testable; wiring it into
/// `lib/screens/addresses.dart` (today hardcoded demo data with a
/// non-functional "Add New Address" button) is a deliberate fast-follow, not
/// done by this change -- see the issue #78 PR description.
abstract interface class DeliveryAddressRepository {
  /// The signed-in profile's saved addresses, default address first, then
  /// most recently created first.
  Future<List<DeliveryAddress>> fetchSavedAddresses();

  Future<DeliveryAddress> create(NewDeliveryAddress address);

  /// Updates the saved address identified by [id]. Only rows owned by the
  /// signed-in profile can ever match, both via RLS and via the repository's
  /// own explicit `profile_id` filter (see the implementation) -- attempting
  /// to update another profile's address id resolves as "not found", not as
  /// a permission error, matching this app's existing RLS-scoped-lookup
  /// convention (see `OrderDetailsSource.fetchOrderById`).
  Future<DeliveryAddress> update(String id, NewDeliveryAddress address);

  Future<void> delete(String id);
}

class SupabaseDeliveryAddressRepository implements DeliveryAddressRepository {
  const SupabaseDeliveryAddressRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  static const _selection =
      'id, label, recipient_name, phone, street, district, city, '
      'is_default, created_at, updated_at';

  String _requireProfileId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Sign in before loading saved addresses.');
    }
    return id;
  }

  @override
  Future<List<DeliveryAddress>> fetchSavedAddresses() async {
    final profileId = _requireProfileId();

    final rows = await _client
        .from('delivery_addresses')
        .select(_selection)
        .eq('profile_id', profileId)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);

    // Parse each row independently: one malformed row must not blank the
    // whole address list for the user -- same defensive approach as
    // SupabaseActivityRepository.fetchActivities (issue #62).
    final addresses = <DeliveryAddress>[];
    for (final row in rows) {
      final rowMap = Map<String, dynamic>.from(row);
      try {
        addresses.add(DeliveryAddress.fromMap(rowMap));
      } on FormatException catch (error, stackTrace) {
        debugPrint(
          'Skipping malformed delivery_addresses row (id: '
          '${rowMap['id']}): $error\n$stackTrace',
        );
      }
    }
    return List.unmodifiable(addresses);
  }

  @override
  Future<DeliveryAddress> create(NewDeliveryAddress address) async {
    final profileId = _requireProfileId();

    final row = await _client
        .from('delivery_addresses')
        .insert({...address.toMap(), 'profile_id': profileId})
        .select(_selection)
        .single();

    return DeliveryAddress.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<DeliveryAddress> update(String id, NewDeliveryAddress address) async {
    final profileId = _requireProfileId();

    final row = await _client
        .from('delivery_addresses')
        .update(address.toMap())
        .eq('id', id)
        .eq('profile_id', profileId)
        .select(_selection)
        .single();

    return DeliveryAddress.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> delete(String id) async {
    final profileId = _requireProfileId();

    await _client
        .from('delivery_addresses')
        .delete()
        .eq('id', id)
        .eq('profile_id', profileId);
  }
}
