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
  });

  final String id;
  final ServiceId serviceId;
  final String title;
  final String? subtitle;
  final String status;
  final DateTime occurredAt;
  final double amount;
  final String detailsRoute;

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
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount?.toString() ?? '');
    if (amount == null || !amount.isFinite || amount < 0) {
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
    );
  }
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
