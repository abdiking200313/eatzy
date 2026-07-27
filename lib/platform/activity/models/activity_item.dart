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

  factory ActivityItem.fromMap(Map<String, dynamic> map) {
    final serviceId = switch (_requiredString(map, 'service_id')) {
      'food' => ServiceId.food,
      'grocery' => ServiceId.grocery,
      'pharmacy' => ServiceId.pharmacy,
      'cleaning' => ServiceId.cleaning,
      final value => throw FormatException(
        'Unsupported activity service: $value',
      ),
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
