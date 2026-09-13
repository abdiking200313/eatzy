/// Real wallet transaction data, mapped from a `public.wallet_transactions`
/// row (see `supabase/schema.sql` / `supabase/migrations/`).
enum WalletTransactionType { topUp, orderPayment, refund, adjustment }

class WalletTransactionRecord {
  const WalletTransactionRecord({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
    this.orderId,
  });

  final String id;
  final WalletTransactionType type;

  /// Integer cents (smallest currency unit), straight from
  /// `wallet_transactions.amount`. Positive is a credit to the wallet
  /// (top-up, refund); negative is a debit (order payment). There is no
  /// separate "is credit" column. Convert to decimal dollars only at display
  /// time, via `AppMoney.formatCents(amount)` — see issue #8, which
  /// standardized every other money value in this app onto the same
  /// convention this column already used.
  final int amount;
  final String description;
  final DateTime createdAt;
  final String? orderId;

  bool get isCredit => amount >= 0;

  static WalletTransactionRecord fromMap(Map<String, dynamic> map) {
    final rawAmount = map['amount'];
    final amountCents = rawAmount is num
        ? rawAmount.round()
        : int.tryParse(rawAmount?.toString() ?? '');
    if (amountCents == null) {
      throw const FormatException('Invalid wallet transaction amount.');
    }
    final createdAt = DateTime.tryParse(_requiredString(map, 'created_at'));
    if (createdAt == null) {
      throw const FormatException('Invalid wallet transaction time.');
    }

    return WalletTransactionRecord(
      id: _requiredString(map, 'id'),
      type: _parseType(_requiredString(map, 'type')),
      amount: amountCents,
      description: _requiredString(map, 'description'),
      createdAt: createdAt.toUtc(),
      orderId: _optionalString(map, 'order_id'),
    );
  }

  static WalletTransactionType _parseType(String raw) => switch (raw) {
    'top_up' => WalletTransactionType.topUp,
    'order_payment' => WalletTransactionType.orderPayment,
    'refund' => WalletTransactionType.refund,
    'adjustment' => WalletTransactionType.adjustment,
    final value => throw FormatException(
      'Unsupported wallet transaction type: $value',
    ),
  };
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Missing required wallet transaction field: $key');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> map, String key) {
  final value = map[key]?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}
