import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../widgets/app_scaffold.dart';
import 'models/wallet_models.dart';
import 'widgets/wallet_balance_card.dart';
import 'widgets/wallet_lists.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  static const List<WalletAction> _actions = [
    WalletAction(icon: Icons.add, label: 'Add Money'),
    WalletAction(icon: Icons.send, label: 'Send'),
  ];

  static const List<WalletPaymentMethod> _paymentMethods = [
    WalletPaymentMethod(
      title: 'Visa Card',
      subtitle: '**** **** **** 4829',
      isDefault: true,
    ),
    WalletPaymentMethod(title: 'Master Card', subtitle: '**** **** **** 2156'),
    WalletPaymentMethod(
      title: 'Bank Transfer',
      subtitle: 'GTBank - Amara Johnson',
    ),
  ];

  static const List<WalletTransaction> _transactions = [
    WalletTransaction(
      title: 'Jollof Feast Order',
      subtitle: 'Order #45782',
      amount: '-NGN 4,500',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDJUXE_bmcF9Zwpl-L25ghBB_DTvx3JZj5MZgzFOKW7p4H2TlIIAq2YJefUGpzVDnNN2vdro1kkmRqFY74fbiwRdWUuPHfAq_SMht1FSREf1nFUeqK5ResE9TzwgXUN5GBTckC-FWuNAyI04gt-K7i4XxAvQQxzpXlXl41A9lxyiYz2l4adWnwvjZhpQ21_EBnGKaZohJMO6S2AT6Jv6i57Lt2pbp9XBLFo5b9kcbV-S-Ei_p3ouce3gqr55Axa4fsbCfR59omjU4pW',
    ),
    WalletTransaction(
      title: 'Wallet Top-up',
      subtitle: '+NGN 10,000',
      amount: '+NGN 10,000',
      isCredit: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'My Wallet',
      showBackButton: true,
      body: ListView(
        padding: const EdgeInsets.all(TwSpacing.x5),
        children: [
          const WalletBalanceCard(balance: 'NGN 15,750.50', actions: _actions),
          const SizedBox(height: TwSpacing.x8),
          const SectionTitle('Payment Methods', fontSize: 18),
          const SizedBox(height: TwSpacing.x5),
          for (final method in _paymentMethods) ...[
            WalletPaymentMethodCard(method: method),
            if (method != _paymentMethods.last)
              const SizedBox(height: TwSpacing.x5),
          ],
          const SizedBox(height: TwSpacing.x8),
          const SectionTitle('Recent Transactions', fontSize: 18),
          const SizedBox(height: TwSpacing.x5),
          for (final transaction in _transactions) ...[
            WalletTransactionRow(transaction: transaction),
            if (transaction != _transactions.last)
              const SizedBox(height: TwSpacing.x5),
          ],
        ],
      ),
    );
  }
}
