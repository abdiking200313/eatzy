import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/service_module.dart';
import '../../error_reporting/error_reporter.dart';
import '../models/activity_item.dart';
import '../models/order_details.dart';

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

  /// [fetchOrderById] plus the order's lines, charges and delivery
  /// address. Same `null` contract.
  Future<OrderDetails?> fetchOrderDetails({
    required String orderId,
    required String serviceId,
  });

  /// A tick/ping stream, not the order data itself: emits an event every
  /// time this order's row changes server-side (e.g. a merchant moving it
  /// to `preparing`/`out_for_delivery`), with no payload of its own.
  /// Callers must refetch via [fetchOrderDetails] on every event rather
  /// than trust any payload shape. Never completes or errors on its own;
  /// cancel the subscription to stop watching.
  Stream<void> watchOrder({required String orderId, required String serviceId});
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
          'amount, details_route, payment_method, payment_status',
        )
        .eq('profile_id', profileId)
        .order('occurred_at', ascending: false)
        .limit(limit);

    // Parse each row independently: one malformed row (missing/blank field,
    // an unparseable date or amount, etc.) must not blank the whole activity
    // list for the user. Skip and log just that row instead.
    final items = <ActivityItem>[];
    for (final row in rows) {
      final rowMap = Map<String, dynamic>.from(row);
      try {
        final item = ActivityItem.fromMap(rowMap);
        if (item != null) {
          items.add(item);
        }
      } on FormatException catch (error, stackTrace) {
        ErrorReporting.instance.reportError(
          error,
          stackTrace,
          context: 'SupabaseActivityRepository.fetchActivities',
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
          'amount, details_route, payment_method, payment_status',
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
      ErrorReporting.instance.reportError(
        error,
        stackTrace,
        context: 'SupabaseActivityRepository.fetchOrderById',
      );
      return null;
    }
  }

  @override
  Future<OrderDetails?> fetchOrderDetails({
    required String orderId,
    required String serviceId,
  }) async {
    final summary = await fetchOrderById(
      orderId: orderId,
      serviceId: serviceId,
    );
    if (summary == null) return null;

    final (table, itemsTable, itemName, extra) = switch (summary.serviceId) {
      ServiceId.food => (
        'food_orders',
        'food_order_items',
        'item_name',
        'restaurant_name, tax',
      ),
      ServiceId.grocery => (
        'grocery_orders',
        'grocery_order_items',
        'product_name',
        'store_name, delivery_slot_label',
      ),
      ServiceId.pharmacy => (
        'pharmacy_orders',
        'pharmacy_order_items',
        'product_name',
        'delivery_instructions',
      ),
      ServiceId.unknown => (null, null, null, null),
    };
    if (table == null || itemsTable == null || itemName == null) return null;

    final itemColumns = [
      itemName,
      'quantity',
      'unit_price',
      if (summary.serviceId == ServiceId.grocery) 'pricing_unit',
    ].join(', ');
    // RLS already scopes each order table to the caller's own rows.
    final row = await _client
        .from(table)
        .select(
          'subtotal, delivery_fee, total, recipient_name, phone, street, '
          'district, city, $extra, $itemsTable($itemColumns)',
        )
        .eq('id', orderId)
        .maybeSingle();
    if (row == null) return null;
    return OrderDetails.fromOrderRow(
      summary,
      Map<String, dynamic>.from(row),
      itemsKey: itemsTable,
      itemNameColumn: itemName,
    );
  }

  @override
  Stream<void> watchOrder({
    required String orderId,
    required String serviceId,
  }) {
    // Same per-vertical table [fetchOrderDetails] reads back from; keyed by
    // `serviceId` (the raw `customer_activity`/route value), not the parsed
    // [ServiceId] enum, since that's what this method is called with.
    final table = switch (serviceId) {
      'food' => 'food_orders',
      'grocery' => 'grocery_orders',
      'pharmacy' => 'pharmacy_orders',
      _ => null,
    };
    if (table == null) {
      return const Stream<void>.empty();
    }

    late final RealtimeChannel channel;
    final controller = StreamController<void>.broadcast(
      onCancel: () => _client.removeChannel(channel),
    );
    // Filtered to this order's own row only (`id` is each order table's
    // primary key, see `supabase/schema.sql`) -- a single realtime
    // subscription per screen, not a firehose of every order on the table.
    channel = _client
        .channel('order-watch:$table:$orderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: orderId,
          ),
          callback: (payload) {
            if (!controller.isClosed) controller.add(null);
          },
        )
        .subscribe();
    return controller.stream;
  }
}
