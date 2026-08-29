import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/theme.dart';
import '../../../platform/localization/app_money.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_scaffold.dart';
import '../data/wallet_repository.dart';
import '../models/wallet_payment_method_record.dart';
import '../models/wallet_transaction_record.dart';
import 'models/wallet_models.dart';
import 'widgets/wallet_balance_card.dart';
import 'widgets/wallet_lists.dart';

class _WalletSnapshot {
  const _WalletSnapshot({
    required this.balance,
    required this.transactions,
    required this.paymentMethods,
  });

  final double balance;
  final List<WalletTransactionRecord> transactions;
  final List<WalletPaymentMethodRecord> paymentMethods;
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, this.walletRepository});

  final WalletRepository? walletRepository;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late Future<_WalletSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadWallet();
  }

  WalletRepository get _repository =>
      widget.walletRepository ??
      SupabaseWalletRepository(client: Supabase.instance.client);

  Future<_WalletSnapshot> _loadWallet() async {
    final repository = _repository;
    final balanceFuture = repository.fetchBalance();
    final transactionsFuture = repository.fetchTransactions();
    final paymentMethodsFuture = repository.fetchPaymentMethods();
    return _WalletSnapshot(
      balance: await balanceFuture,
      transactions: await transactionsFuture,
      paymentMethods: await paymentMethodsFuture,
    );
  }

  void _retry() {
    setState(() {
      _future = _loadWallet();
    });
  }

  void _showComingSoon(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'My Wallet',
      showBackButton: true,
      body: FutureBuilder<_WalletSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(TwSpacing.x8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Wallet could not be loaded. Please try again.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: TwSpacing.x4),
                    FilledButton(
                      onPressed: _retry,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final snapshotData = snapshot.data!;
          final actions = [
            WalletAction(
              icon: Icons.add,
              label: 'Add Money',
              onTap: () => _showComingSoon('Adding money is coming soon.'),
            ),
            WalletAction(
              icon: Icons.send,
              label: 'Send',
              onTap: () => _showComingSoon('Sending money is coming soon.'),
            ),
          ];

          return ListView(
            padding: const EdgeInsets.all(TwSpacing.x5),
            children: [
              WalletBalanceCard(
                balance: AppMoney.format(snapshotData.balance),
                actions: actions,
              ),
              const SizedBox(height: TwSpacing.rhythmSection),
              const SectionTitle('Payment Methods', fontSize: 18),
              const SizedBox(height: TwSpacing.rhythmDefault),
              if (snapshotData.paymentMethods.isEmpty)
                _EmptySectionCard(
                  message: 'No payment methods added yet.',
                  actionLabel: 'Add a payment method',
                  onAction: () => _showComingSoon(
                    'Adding a payment method is coming soon.',
                  ),
                )
              else
                OutlinedCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final method in snapshotData.paymentMethods) ...[
                        WalletPaymentMethodRow(method: method),
                        if (method != snapshotData.paymentMethods.last)
                          const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: TwSpacing.rhythmSection),
              const SectionTitle('Recent Transactions', fontSize: 18),
              const SizedBox(height: TwSpacing.rhythmDefault),
              if (snapshotData.transactions.isEmpty)
                const _EmptySectionCard(message: 'No transactions yet.')
              else
                OutlinedCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final transaction in snapshotData.transactions) ...[
                        WalletTransactionRow(transaction: transaction),
                        if (transaction != snapshotData.transactions.last)
                          const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptySectionCard extends StatelessWidget {
  const _EmptySectionCard({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TwText.textSm.copyWith(color: TwColors.textMuted),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: TwSpacing.x3),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
