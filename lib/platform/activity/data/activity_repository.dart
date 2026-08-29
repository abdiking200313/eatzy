import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity_item.dart';

abstract interface class ActivitySource {
  Future<List<ActivityItem>> fetchActivities({int limit = 100});
}

abstract interface class ActivityRepository implements ActivitySource {}

class SupabaseActivityRepository implements ActivityRepository {
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
}
