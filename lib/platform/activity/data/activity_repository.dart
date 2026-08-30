import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity_item.dart';

abstract interface class ActivitySource {
  Future<List<ActivityItem>> fetchActivities({int limit = 100});
}

abstract interface class ActivityRepository implements ActivitySource {}

/// Looks up a single real order by id, scoped to one service vertical.
/// Backs [TrackOrderScreen] — kept as its own small interface rather than
/// folded into [ActivityRepository] so existing `ActivityRepository` fakes
/// (list-only) don't need to grow an unrelated method.
abstract interface class OrderDetailsSource {
  /// Returns `null` when no matching row exists — either the id/service
  /// pair doesn't exist, or row-level security has already scoped it away
  /// because it belongs to a different profile. Those two cases are
  /// indistinguishable from here by design (RLS should never leak which one
  /// happened), so callers must treat both as a plain "order not found".
  Future<ActivityItem?> fetchOrderById({
    required String orderId,
    required String serviceId,
  });
}

abstract interface class OrderDetailsRepository implements OrderDetailsSource {}

class SupabaseActivityRepository
    implements ActivityRepository, OrderDetailsRepository {
  const SupabaseActivityRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<List<ActivityItem>> fetchActivities({int limit = 100}) async {
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }
    final profileId = _client.auth.currentUser?.id;
    if (profileId == null) {
      throw StateError('Sign in before loading customer activity.');
    }

    final rows = await _client
        .from('customer_activity')
        .select(
          'id, profile_id, service_id, title, subtitle, status, occurred_at, '
          'amount, details_route',
        )
        .eq('profile_id', profileId)
        .order('occurred_at', ascending: false)
        .limit(limit);

    // Parse each row independently: one malformed row (missing/blank field,
    // an unparseable date or amount, etc.) must not blank the whole activity
    // list for the user. Skip and log just that row instead — see #62.
    final items = <ActivityItem>[];
    for (final row in rows) {
      final rowMap = Map<String, dynamic>.from(row);
      try {
        final item = ActivityItem.fromMap(rowMap);
        if (item != null) {
          items.add(item);
        }
      } on FormatException catch (error, stackTrace) {
        debugPrint(
          'Skipping malformed customer_activity row (id: '
          '${rowMap['id']}): $error\n$stackTrace',
        );
      }
    }
    return List.unmodifiable(items);
  }

  @override
  Future<ActivityItem?> fetchOrderById({
    required String orderId,
    required String serviceId,
  }) async {
    final profileId = _client.auth.currentUser?.id;
    if (profileId == null) {
      throw StateError('Sign in before loading order details.');
    }

    // `.eq('profile_id', ...)` is redundant with RLS (which already scopes
    // every `customer_activity` row to the caller) but kept explicit for
    // the same reason fetchActivities keeps it: the intent should be
    // readable from the query itself, not only from the policy.
    final row = await _client
        .from('customer_activity')
        .select(
          'id, profile_id, service_id, title, subtitle, status, occurred_at, '
          'amount, details_route',
        )
        .eq('profile_id', profileId)
        .eq('id', orderId)
        .eq('service_id', serviceId)
        .maybeSingle();
    if (row == null) {
      return null;
    }

    final rowMap = Map<String, dynamic>.from(row);
    try {
      return ActivityItem.fromMap(rowMap);
    } on FormatException catch (error, stackTrace) {
      debugPrint(
        'Order lookup returned a malformed customer_activity row (id: '
        '${rowMap['id']}): $error\n$stackTrace',
      );
      return null;
    }
  }
}
