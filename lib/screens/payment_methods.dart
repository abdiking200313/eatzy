import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/app_misc.dart';
import '../widgets/app_scaffold.dart';

class PaymentMethodsScreenFull extends StatelessWidget {
  const PaymentMethodsScreenFull({super.key});

  static const List<_PaymentMethod> _paymentMethods = [
    _PaymentMethod(
      type: 'Visa',
      icon: Icons.credit_card,
      lastFour: '4242',
      expiry: '12/26',
      isDefault: true,
    ),
    _PaymentMethod(
      type: 'Mastercard',
      icon: Icons.credit_card,
      lastFour: '8765',
      expiry: '08/25',
    ),
    _PaymentMethod(
      type: 'American Express',
      icon: Icons.credit_card,
      lastFour: '1234',
      expiry: '06/27',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Payment Methods',
      showBackButton: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GradientActionButton(
              label: 'Add New Card',
              onPressed: () {},
              icon: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionTitle('Saved Cards'),
            const SizedBox(height: AppSpacing.md),
            for (final method in _paymentMethods) ...[
              _PaymentMethodCard(method: method),
              if (method != _paymentMethods.last)
                const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
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
      borderColor:
          method.isDefault ? AppColors.primary : AppColors.outlineVariant,
      borderWidth: method.isDefault ? 2 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(method.icon, color: AppColors.primary, size: 24),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(method.type, style: AppTextStyles.cardTitleSm()),
                      const SizedBox(height: 2),
                      Text(
                        '**** ${method.lastFour}',
                        style: AppTextStyles.labelSm().copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (method.isDefault)
                const StatusPill(
                  label: 'Default',
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.onPrimaryContainer,
                  fontSize: 10,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Expires', style: AppTextStyles.labelSm()),
                  const SizedBox(height: 2),
                  Text(method.expiry, style: AppTextStyles.cardTitleSm()),
                ],
              ),
              Row(
                children: [
                  if (!method.isDefault)
                    OutlinedCard(
                      onTap: () {},
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      backgroundColor: Colors.transparent,
                      borderColor: AppColors.outline,
                      borderRadius: AppRadii.md,
                      child: Text(
                        'Set Default',
                        style: AppTextStyles.labelSm().copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedCard(
                    onTap: () {},
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    backgroundColor: Colors.transparent,
                    borderColor: AppColors.error,
                    borderRadius: AppRadii.md,
                    child: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentMethod {
  const _PaymentMethod({
    required this.type,
    required this.icon,
    required this.lastFour,
    required this.expiry,
    this.isDefault = false,
  });

  final String type;
  final IconData icon;
  final String lastFour;
  final String expiry;
  final bool isDefault;
}
