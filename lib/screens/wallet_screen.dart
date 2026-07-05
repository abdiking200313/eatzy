import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/app_misc.dart';
import '../widgets/app_scaffold.dart';

class WalletScreenFull extends StatelessWidget {
  const WalletScreenFull({super.key});

  static const List<_WalletAction> _actions = [
    _WalletAction(icon: Icons.add, label: 'Add Money'),
    _WalletAction(icon: Icons.send, label: 'Send'),
  ];

  static const List<_PaymentMethod> _paymentMethods = [
    _PaymentMethod(
      title: 'Visa Card',
      subtitle: '**** **** **** 4829',
      isDefault: true,
    ),
    _PaymentMethod(
      title: 'Master Card',
      subtitle: '**** **** **** 2156',
    ),
    _PaymentMethod(
      title: 'Bank Transfer',
      subtitle: 'GTBank - Amara Johnson',
    ),
  ];

  static const List<_WalletTransaction> _transactions = [
    _WalletTransaction(
      title: 'Jollof Feast Order',
      subtitle: 'Order #45782',
      amount: '-NGN 4,500',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDJUXE_bmcF9Zwpl-L25ghBB_DTvx3JZj5MZgzFOKW7p4H2TlIIAq2YJefUGpzVDnNN2vdro1kkmRqFY74fbiwRdWUuPHfAq_SMht1FSREf1nFUeqK5ResE9TzwgXUN5GBTckC-FWuNAyI04gt-K7i4XxAvQQxzpXlXl41A9lxyiYz2l4adWnwvjZhpQ21_EBnGKaZohJMO6S2AT6Jv6i57Lt2pbp9XBLFo5b9kcbV-S-Ei_p3ouce3gqr55Axa4fsbCfR59omjU4pW',
    ),
    _WalletTransaction(
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: AppColors.fireSunGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Balance',
                  style: AppTextStyles.labelSm().copyWith(
                    color: Colors.white.withOpacityValue(0.8),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                Text(
                  'NGN 15,750.50',
                  style: AppTextStyles.h1().copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    for (final action in _actions) ...[
                      Expanded(child: _WalletActionButton(action: action)),
                      if (action != _actions.last)
                        const SizedBox(width: AppSpacing.lg),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionTitle('Payment Methods', fontSize: 18),
          const SizedBox(height: AppSpacing.lg),
          for (final method in _paymentMethods) ...[
            _PaymentMethodCard(method: method),
            if (method != _paymentMethods.last)
              const SizedBox(height: AppSpacing.lg),
          ],
          const SizedBox(height: AppSpacing.xl),
          const SectionTitle('Recent Transactions', fontSize: 18),
          const SizedBox(height: AppSpacing.lg),
          for (final transaction in _transactions) ...[
            _TransactionRow(transaction: transaction),
            if (transaction != _transactions.last)
              const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}

class _WalletActionButton extends StatelessWidget {
  const _WalletActionButton({required this.action});

  final _WalletAction action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacityValue(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(action.icon, color: Colors.white),
          const SizedBox(width: AppSpacing.base),
          Text(
            action.label,
            style: AppTextStyles.labelBold().copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({required this.method});

  final _PaymentMethod method;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      backgroundColor: Colors.white,
      borderRadius: 16,
      borderColor:
          method.isDefault ? AppColors.primary : AppColors.outlineVariant,
      borderWidth: method.isDefault ? 2 : 1,
      child: Row(
        children: [
          const Icon(Icons.payment, color: AppColors.primary),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(method.title, style: AppTextStyles.cardTitleSm()),
                Text(
                  method.subtitle,
                  style: AppTextStyles.labelSm().copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (method.isDefault)
            const StatusPill(
              label: 'Default',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              fontSize: 10,
            ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final _WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (transaction.imageUrl != null)
          NetworkAvatar(
            imageUrl: transaction.imageUrl!,
            radius: 25,
          )
        else
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(AppRadii.full),
            ),
            child: const Icon(Icons.add, color: AppColors.onSurface),
          ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(transaction.title, style: AppTextStyles.cardTitleSm()),
              Text(
                transaction.subtitle,
                style: AppTextStyles.labelSm().copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Text(
          transaction.amount,
          style: AppTextStyles.labelBold().copyWith(
            color: transaction.isCredit
                ? AppColors.secondary
                : AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}

class _WalletAction {
  const _WalletAction({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

class _PaymentMethod {
  const _PaymentMethod({
    required this.title,
    required this.subtitle,
    this.isDefault = false,
  });

  final String title;
  final String subtitle;
  final bool isDefault;
}

class _WalletTransaction {
  const _WalletTransaction({
    required this.title,
    required this.subtitle,
    required this.amount,
    this.imageUrl,
    this.isCredit = false,
  });

  final String title;
  final String subtitle;
  final String amount;
  final String? imageUrl;
  final bool isCredit;
}
