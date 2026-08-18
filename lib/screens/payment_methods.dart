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
        padding: const EdgeInsets.all(TwSpacing.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {},
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'Add New Card',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: TwSpacing.x2),
                    Icon(Icons.add_rounded, size: 19),
                  ],
                ),
              ),
            ),
            const SizedBox(height: TwSpacing.rhythmSection),
            const SectionTitle('Saved Cards'),
            const SizedBox(height: TwSpacing.rhythmDefault),
            OutlinedCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final method in _paymentMethods) ...[
                    _PaymentMethodRow(method: method),
                    if (method != _paymentMethods.last)
                      const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodRow extends StatelessWidget {
  const _PaymentMethodRow({required this.method});

  final _PaymentMethod method;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TwSpacing.x4,
        vertical: TwSpacing.rhythmDefault,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ServiceIconChip(
                icon: method.icon,
                background: palette.soft,
                foreground: palette.accent,
              ),
              const SizedBox(width: TwSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.type,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TwText.fontBoldSm(),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '**** ${method.lastFour}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TwText.textXs().copyWith(
                        color: TwColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (method.isDefault) ...[
                const SizedBox(width: TwSpacing.x2),
                StatusPill(
                  label: 'Default',
                  backgroundColor: palette.soft,
                  foregroundColor: palette.accent,
                  fontSize: 10,
                ),
              ],
            ],
          ),
          const SizedBox(height: TwSpacing.rhythmDefault),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: TwSpacing.x2,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Expires', style: TwText.textXs()),
                  const SizedBox(height: 2),
                  Text(method.expiry, style: TwText.fontBoldSm()),
                ],
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
