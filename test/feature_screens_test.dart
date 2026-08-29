import 'package:chowflow/features/checkout/presentation/checkout_screen.dart';
import 'package:chowflow/features/profile/presentation/profile_screen.dart';
import 'package:chowflow/features/rewards/presentation/rewards_screen.dart';
import 'package:chowflow/features/settings/presentation/settings_screen.dart';
import 'package:chowflow/features/support/presentation/support_screen.dart';
import 'package:chowflow/features/wallet/data/wallet_repository.dart';
import 'package:chowflow/features/wallet/models/wallet_payment_method_record.dart';
import 'package:chowflow/features/wallet/models/wallet_transaction_record.dart';
import 'package:chowflow/features/wallet/presentation/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('representative moved feature screens render', (tester) async {
    final cases = <({Widget screen, String title})>[
      (screen: const CheckoutScreen(), title: 'Checkout'),
      (screen: const ProfileScreen(), title: 'Profile'),
      (screen: const RewardsScreen(), title: 'Rewards & Achievements'),
      (screen: const SettingsScreen(), title: 'Settings'),
      (screen: const SupportScreen(), title: 'Help & Support'),
      (
        screen: WalletScreen(walletRepository: _FakeWalletRepository()),
        title: 'My Wallet',
      ),
    ];

    for (final testCase in cases) {
      await tester.pumpWidget(MaterialApp(home: testCase.screen));
      await tester.pump();

      expect(
        find.text(testCase.title),
        findsOneWidget,
        reason: '${testCase.screen.runtimeType} should render its title',
      );
    }
  });
}

class _FakeWalletRepository implements WalletRepository {
  @override
  Future<double> fetchBalance() async => 120.5;

  @override
  Future<List<WalletTransactionRecord>> fetchTransactions({
    int limit = 20,
  }) async => const [];

  @override
  Future<List<WalletPaymentMethodRecord>> fetchPaymentMethods() async =>
      const [];
}
