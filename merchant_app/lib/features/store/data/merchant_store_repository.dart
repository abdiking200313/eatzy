import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../platform/slug_id.dart';
import '../models/merchant_store.dart';
import '../models/merchant_vertical.dart';

/// Data access for the signed-in merchant's own store (issue #133).
///
/// Every method here is scoped by `owner_id`, both because the schema's RLS
/// makes any other row unreachable
/// (`supabase/migrations/20260830130000_add_merchant_catalog_write_policies.sql`:
/// `owner_id = auth.uid()` on select/update/delete, plus a role check on
/// insert) and, per issue #133, because the client itself should never
/// attempt to query or mutate a store it does not own even if a bug in a
/// future policy change made that briefly possible server-side.
abstract interface class MerchantStoreRepository {
  /// Looks for a store owned by [ownerId] across all three verticals (food,
  /// then grocery, then pharmacy) and returns the first match, or `null` if
  /// the merchant does not have a store yet in any vertical. A merchant is
  /// modeled as owning at most one store per vertical, and in practice one
  /// store total for v1 -- see `merchant_vertical.dart`'s header and issue
  /// #133's own scope note ("don't invent a multi-store switcher unless the
  /// data model already requires one").
  Future<MerchantStore?> fetchOwnStore(String ownerId);

  /// Creates a new store for [ownerId] in [vertical]. Requires
  /// `profiles.role` to already be `merchant`/`admin` -- the insert RLS
  /// policy re-checks this server-side regardless of what the client sends.
  Future<MerchantStore> createStore({
    required MerchantVertical vertical,
    required String ownerId,
    required String name,
    required String location,
    String? description,
  });

  /// Updates the caller's own store. [store] identifies which row/vertical
  /// to update; the other parameters are the new field values.
  Future<MerchantStore> updateStore(
    MerchantStore store, {
    required String ownerId,
    required String name,
    required String location,
    required bool isOpen,
    String? description,
    String? imageUrl,
  });
}

class SupabaseMerchantStoreRepository implements MerchantStoreRepository {
  // `client` is deliberately a public-looking named parameter (used
  // cross-file, e.g. from `MerchantStoreController.supabase`); an
  // initializing formal would force the external name to be the private
  // `_client`, which isn't usable outside this file.
  SupabaseMerchantStoreRepository({required SupabaseClient client})
    // ignore: prefer_initializing_formals
    : _client = client;

  final SupabaseClient _client;

  static const List<MerchantVertical> _verticalsInLookupOrder = [
    MerchantVertical.food,
    MerchantVertical.grocery,
    MerchantVertical.pharmacy,
  ];

  List<String> _selectColumns(MerchantVertical vertical) => [
    'id',
    'name',
    vertical.storeLocationColumn,
    vertical.storeActiveColumn,
    if (vertical.storeSupportsDescription) 'description',
    if (vertical.storeSupportsImage) 'image_url',
  ];

  @override
  Future<MerchantStore?> fetchOwnStore(String ownerId) async {
    for (final vertical in _verticalsInLookupOrder) {
      final row = await _client
          .from(vertical.storeTable)
          .select(_selectColumns(vertical).join(', '))
          .eq('owner_id', ownerId)
          .maybeSingle();
      if (row != null) {
        return MerchantStore.fromMap(row, vertical: vertical);
      }
    }
    return null;
  }

  @override
  Future<MerchantStore> createStore({
    required MerchantVertical vertical,
    required String ownerId,
    required String name,
    required String location,
    String? description,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const FormatException('A store name is required.');
    }

    final payload = <String, dynamic>{
      'owner_id': ownerId,
      'name': trimmedName,
      vertical.storeLocationColumn: location.trim(),
      if (vertical.storeSupportsDescription) 'description': description?.trim(),
    };
    if (!vertical.storeIdIsServerGenerated) {
      payload['id'] = generateSlugId(trimmedName);
    }

    final row = await _client
        .from(vertical.storeTable)
        .insert(payload)
        .select(_selectColumns(vertical).join(', '))
        .single();
    return MerchantStore.fromMap(row, vertical: vertical);
  }

  @override
  Future<MerchantStore> updateStore(
    MerchantStore store, {
    required String ownerId,
    required String name,
    required String location,
    required bool isOpen,
    String? description,
    String? imageUrl,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const FormatException('A store name is required.');
    }

    final vertical = store.vertical;
    final payload = <String, dynamic>{
      'name': trimmedName,
      vertical.storeLocationColumn: location.trim(),
      vertical.storeActiveColumn: isOpen,
      if (vertical.storeSupportsDescription) 'description': description?.trim(),
      if (vertical.storeSupportsImage) 'image_url': imageUrl?.trim(),
    };

    final row = await _client
        .from(vertical.storeTable)
        .update(payload)
        // Belt-and-braces client-side scoping on top of the server-side RLS
        // predicate (issue #133: "the UI should also only ever query/mutate
        // the caller's own store").
        .eq('id', store.id)
        .eq('owner_id', ownerId)
        .select(_selectColumns(vertical).join(', '))
        .single();
    return MerchantStore.fromMap(row, vertical: vertical);
  }
}
