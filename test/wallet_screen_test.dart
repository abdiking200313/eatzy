import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/wallet/data/wallet_repository.dart';
import 'package:chowflow/features/wallet/models/wallet_payment_method_record.dart';
import 'package:chowflow/features/wallet/models/wallet_transaction_record.dart';
import 'package:chowflow/features/wallet/presentation/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WalletTransactionRecord.fromMap', () {
    test('parses integer-cents amount into signed decimal dollars', () {
      final credit = WalletTransactionRecord.fromMap({
        'id': 'txn-1',
        'order_id': null,
        'type': 'top_up',
        'amount': 5000,
        'description': 'Wallet Top-up',
        'created_at': DateTime.utc(2026, 8, 1).toIso8601String(),
      });
      expect(credit.amount, 50.0);
      expect(credit.isCredit, isTrue);

      final debit = WalletTransactionRecord.fromMap({
        'id': 'txn-2',
        'order_id': '45782',
        'type': 'order_payment',
        'amount': -1850,
        'description': 'Jollof Feast Order',
        'created_at': DateTime.utc(2026, 8, 2).toIso8601String(),
      });
      expect(debit.amount, -18.5);
      expect(debit.isCredit, isFalse);
      expect(debit.orderId, '45782');
    });

    test('rejects an unsupported transaction type', () {
      expect(
        () => WalletTransactionRecord.fromMap({
          'id': 'txn-3',
          'type': 'not-a-real-type',
          'amount': 100,
          'description': 'Mystery',
          'created_at': DateTime.utc(2026, 8, 1).toIso8601String(),
        }),
        throwsFormatException,
      );
    });
  });

  group('WalletScreen', () {
    testWidgets('renders real balance, transactions, and payment methods', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: WalletScreen(walletRepository: _FakeWalletRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(r'$120.50'), findsOneWidget);
      expect(find.text('Visa Card'), findsOneWidget);
      expect(find.text('**** **** **** 4829'), findsOneWidget);
      expect(find.text('Jollof Feast Order'), findsOneWidget);
      expect(find.text('Order #45782'), findsOneWidget);
      expect(find.text(r'-$18.50'), findsOneWidget);
      expect(find.text('Wallet Top-up'), findsOneWidget);
      expect(find.text(r'+$50.00'), findsOneWidget);
    });

    testWidgets('shows empty states when there is no real data yet', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: WalletScreen(walletRepository: _EmptyWalletRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(r'$0.00'), findsOneWidget);
      expect(find.text('No payment methods added yet.'), findsOneWidget);
      expect(find.text('No transactions yet.'), findsOneWidget);
    });

    testWidgets('shows a retry action when loading fails', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: WalletScreen(walletRepository: _FailingWalletRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Wallet could not be loaded. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}

class _FakeWalletRepository implements WalletRepository {
  @override
  Future<double> fetchBalance() async => 120.5;

  @override
  Future<List<WalletTransactionRecord>> fetchTransactions({
    int limit = 20,
  }) async => [
    WalletTransactionRecord(
      id: 'txn-1',
      type: WalletTransactionType.orderPayment,
      amount: -18.5,
      description: 'Jollof Feast Order',
      createdAt: DateTime.utc(2026, 8, 2),
      orderId: '45782',
    ),
    WalletTransactionRecord(
      id: 'txn-2',
      type: WalletTransactionType.topUp,
      amount: 50,
      description: 'Wallet Top-up',
      createdAt: DateTime.utc(2026, 8, 1),
    ),
  ];

  @override
  Future<List<WalletPaymentMethodRecord>> fetchPaymentMethods() async => const [
    WalletPaymentMethodRecord(
      id: 'pm-1',
      brand: 'Visa Card',
      lastFour: '4829',
      isDefault: true,
    ),
  ];
}

class _EmptyWalletRepository implements WalletRepository {
  @override
  Future<double> fetchBalance() async => 0;

  @override
  Future<List<WalletTransactionRecord>> fetchTransactions({
    int limit = 20,
  }) async => const [];

  @override
  Future<List<WalletPaymentMethodRecord>> fetchPaymentMethods() async =>
      const [];
}

class _FailingWalletRepository implements WalletRepository {
  @override
  Future<double> fetchBalance() async =>
      throw StateError('boom: balance query failed');

  @override
  Future<List<WalletTransactionRecord>> fetchTransactions({
    int limit = 20,
  }) async => const [];

  @override
  Future<List<WalletPaymentMethodRecord>> fetchPaymentMethods() async =>
      const [];
}
