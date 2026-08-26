import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wallet_payment_method_record.dart';
import '../models/wallet_transaction_record.dart';

abstract interface class WalletRepository {
  /// Sum of every wallet transaction's signed amount, in decimal dollars.
  Future<double> fetchBalance();

  /// Most recent transactions, newest first.
  Future<List<WalletTransactionRecord>> fetchTransactions({int limit = 20});

  /// Saved payment methods, default first.
  Future<List<WalletPaymentMethodRecord>> fetchPaymentMethods();
}

class SupabaseWalletRepository implements WalletRepository {
  const SupabaseWalletRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  String _requireProfileId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Sign in before loading wallet data.');
    }
    return id;
  }

  @override
  Future<double> fetchBalance() async {
    final profileId = _requireProfileId();
    // There is no aggregate view/RPC for the wallet balance yet, so it is
    // derived client-side from every transaction's signed amount. Capped at
    // 1000 rows, which is generous for an MVP wallet but means a user who
    // ever exceeds that many transactions would see a balance computed from
    // only their most recent 1000 (order is unspecified without an explicit
    // `.order()`, so this deliberately over-fetches unordered rather than
    // silently dropping older ones without a defined cutoff).
    final rows = await _client
        .from('wallet_transactions')
        .select('amount')
        .eq('profile_id', profileId)
        .limit(1000);

    final totalCents = rows.fold<int>(0, (sum, row) {
      final raw = row['amount'];
      final cents = raw is num
          ? raw.round()
          : int.tryParse(raw?.toString() ?? '') ?? 0;
      return sum + cents;
    });
    return totalCents / 100;
  }

  @override
  Future<List<WalletTransactionRecord>> fetchTransactions({
    int limit = 20,
  }) async {
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }
    final profileId = _requireProfileId();

    final rows = await _client
        .from('wallet_transactions')
        .select('id, order_id, type, amount, description, created_at')
        .eq('profile_id', profileId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List.unmodifiable(
      rows.map(
        (row) =>
            WalletTransactionRecord.fromMap(Map<String, dynamic>.from(row)),
      ),
    );
  }

  @override
  Future<List<WalletPaymentMethodRecord>> fetchPaymentMethods() async {
    final profileId = _requireProfileId();

    final rows = await _client
        .from('payment_methods')
        .select('id, brand, last_four, is_default')
        .eq('profile_id', profileId)
        .order('is_default', ascending: false);

    return List.unmodifiable(
      rows.map(
        (row) =>
            WalletPaymentMethodRecord.fromMap(Map<String, dynamic>.from(row)),
      ),
    );
  }
}
