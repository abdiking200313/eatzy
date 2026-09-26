import '../../../app/app_routes.dart';
import '../../../app/service_module.dart';

class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.serviceId,
    required this.title,
    required this.status,
    required this.occurredAt,
    required this.amount,
    required this.detailsRoute,
    this.subtitle,
    this.paymentMethod,
    this.paymentStatus,
  });

  final String id;
  final ServiceId serviceId;
  final String title;
  final String? subtitle;
  final String status;
  final DateTime occurredAt;

  /// In integer cents — see issue #8. Convert to decimal dollars only at
  /// display time, via `AppMoney.formatCents(amount)`.
  final int amount;
  final String detailsRoute;

  /// Raw `payment_method` / `payment_status` values from the order row (see
  /// issue #30 — cash-on-delivery-only launch scaffolding on
  /// `food_orders`/`grocery_orders`/`pharmacy_orders`). Null for an
  /// [ActivityItem] built locally right after placing an order rather than
  /// read back from `customer_activity`, or for a row from before this
  /// column existed. Today's only real values are `cash_on_delivery` and
  /// `pending_collection`; [TrackOrderScreen] renders them with
  /// [paymentMethodLabel]/[paymentStatusLabel] rather than the raw snake_case
  /// value.
  final String? paymentMethod;
  final String? paymentStatus;

  /// Returns `null` for a row whose `service_id` is a legacy, no-longer
  /// supported service (currently just `'cleaning'`, removed in #50) so it
  /// is silently dropped from history views instead of breaking the whole
  /// activity list.
  ///
  /// Any other unrecognized `service_id` falls back to [ServiceId.unknown]
  /// rather than throwing (see #62): a single row with a service id this
  /// client doesn't (yet) recognize should render as a generic activity
  /// entry, not take down the rest of the list. Other malformed fields on
  /// this row (missing title/status, an unparseable date/amount, etc.) still
  /// throw a [FormatException] from this method — [ActivityRepository]
  /// catches that per row and skips just the bad row, see
  /// `activity_repository.dart`.
  static ActivityItem? fromMap(Map<String, dynamic> map) {
    final rawServiceId = _requiredString(map, 'service_id');
    if (rawServiceId == 'cleaning') {
      return null;
    }
    final serviceId = switch (rawServiceId) {
      'food' => ServiceId.food,
      'grocery' => ServiceId.grocery,
      'pharmacy' => ServiceId.pharmacy,
      _ => ServiceId.unknown,
    };
    final occurredAt = DateTime.tryParse(_requiredString(map, 'occurred_at'));
    if (occurredAt == null) {
      throw const FormatException('Invalid activity occurrence time.');
    }
    final rawAmount = map['amount'];
    final amount = rawAmount is num
        ? rawAmount.round()
        : int.tryParse(rawAmount?.toString() ?? '');
    if (amount == null || amount < 0) {
      throw const FormatException('Invalid activity amount.');
    }

    return ActivityItem(
      id: _requiredString(map, 'id'),
      serviceId: serviceId,
      title: _requiredString(map, 'title'),
      subtitle: _optionalString(map, 'subtitle'),
      status: _requiredString(map, 'status'),
      occurredAt: occurredAt.toUtc(),
      amount: amount,
      detailsRoute: _requiredString(map, 'details_route'),
      paymentMethod: _optionalString(map, 'payment_method'),
      paymentStatus: _optionalString(map, 'payment_status'),
    );
  }

  /// A human-readable label for [paymentMethod], falling back to `null` when
  /// it hasn't been loaded (see the field doc). Only `cash_on_delivery` is a
  /// real value today (issue #30); any other raw value still renders as
  /// something readable instead of disappearing.
  String? get paymentMethodLabel => switch (paymentMethod) {
    null => null,
    'cash_on_delivery' => 'Cash on delivery',
    final other => other,
  };

  /// The order details page for this order, or `null` for a
  /// [ServiceId.unknown] row: [fromMap] has already discarded its raw
  /// `service_id` (see #62), so there is nothing real to key the lookup on.
  String? get orderDetailsPath {
    final rawServiceId = switch (serviceId) {
      ServiceId.food => 'food',
      ServiceId.grocery => 'grocery',
      ServiceId.pharmacy => 'pharmacy',
      ServiceId.unknown => null,
    };
    if (rawServiceId == null) return null;
    return AppRoutes.trackOrderDetailsPath(
      serviceId: rawServiceId,
      orderId: id,
    );
  }

  /// A human-readable label for [paymentStatus]. See [paymentMethodLabel].
  String? get paymentStatusLabel => switch (paymentStatus) {
    null => null,
    'pending_collection' => 'Pending collection',
    'collected' => 'Collected',
    'refunded' => 'Refunded',
    final other => other,
  };
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Missing required activity field: $key');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> map, String key) {
  final value = map[key]?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}
