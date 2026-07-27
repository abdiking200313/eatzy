import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/app_misc.dart';
import '../widgets/app_scaffold.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

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
        padding: const EdgeInsets.all(TwSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {},
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Add New Card'),
                    SizedBox(width: TwSpacing.x2),
                    Icon(Icons.add_rounded, size: 19),
                  ],
                ),
              ),
            ),
            const SizedBox(height: TwSpacing.x5),
            const SectionTitle('Saved Cards'),
            const SizedBox(height: TwSpacing.x4),
            for (final method in _paymentMethods) ...[
              _PaymentMethodCard(method: method),
              if (method != _paymentMethods.last)
                const SizedBox(height: TwSpacing.x4),
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
    final palette = context.serviceColors;
    final colorScheme = Theme.of(context).colorScheme;
    return OutlinedCard(
      padding: const EdgeInsets.all(TwSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(method.icon, color: palette.accent, size: 24),
                  const SizedBox(width: TwSpacing.x3),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(method.type, style: TwText.fontBoldSm()),
                      const SizedBox(height: 2),
                      Text(
                        '**** ${method.lastFour}',
                        style: TwText.textXs().copyWith(
                          color: TwColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (method.isDefault)
                StatusPill(
                  label: 'Default',
                  backgroundColor: palette.soft,
                  foregroundColor: palette.accent,
                  fontSize: 10,
                ),
            ],
          ),
          const SizedBox(height: TwSpacing.x4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Expires', style: TwText.textXs()),
                  const SizedBox(height: 2),
                  Text(method.expiry, style: TwText.fontBoldSm()),
                ],
              ),
              Row(
                children: [
                  if (!method.isDefault)
                    TextButton(
                      onPressed: () {},
                      child: const Text('Set Default'),
                    ),
                  const SizedBox(width: TwSpacing.x2),
                  IconButton.outlined(
                    tooltip: 'Delete ${method.type}',
                    onPressed: () {},
                    color: colorScheme.error,
                    icon: const Icon(Icons.delete_outline, size: 18),
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
