import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/app_misc.dart';
import '../widgets/app_scaffold.dart';

class CheckoutScreenFull extends StatefulWidget {
  const CheckoutScreenFull({super.key});

  @override
  State<CheckoutScreenFull> createState() => _CheckoutScreenFullState();
}

class _CheckoutScreenFullState extends State<CheckoutScreenFull> {
  static const List<_CheckoutItem> _items = [
    _CheckoutItem(name: 'Jollof Rice', price: 'NGN 2,500', quantity: 2),
    _CheckoutItem(name: 'Grilled Chicken', price: 'NGN 4,500', quantity: 1),
    _CheckoutItem(name: 'Plantain Chips', price: 'NGN 1,500', quantity: 1),
  ];

  static const List<_PaymentChoice> _paymentOptions = [
    _PaymentChoice(title: 'Credit Card', subtitle: 'Visa ending in 4242'),
    _PaymentChoice(title: 'Digital Wallet', subtitle: 'Google Pay'),
    _PaymentChoice(title: 'Cash', subtitle: 'Pay on delivery'),
  ];

  int _selectedPayment = 0;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Checkout',
      showBackButton: true,
      body: ListView(
        padding: const EdgeInsets.all(TwSpacing.x5),
        children: [
          OutlinedCard(
            backgroundColor: Colors.white,
            borderRadius: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Order Summary', fontSize: 18),
                const SizedBox(height: TwSpacing.x5),
                for (final item in _items) ...[
                  _CheckoutItemRow(item: item),
                  if (item != _items.last) const SizedBox(height: TwSpacing.x4),
                ],
                const Divider(height: 32),
                const SummaryRow(label: 'Subtotal', value: 'NGN 14,500'),
                const SizedBox(height: TwSpacing.x4),
                const SummaryRow(label: 'Tax', value: 'NGN 1,450'),
                const SizedBox(height: TwSpacing.x4),
                const SummaryRow(label: 'Delivery Fee', value: 'NGN 1,000'),
                const SizedBox(height: TwSpacing.x4),
                Container(
                  padding: const EdgeInsets.all(TwSpacing.x4),
                  decoration: BoxDecoration(
                    color: TwColors.cardMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_offer_outlined,
                        color: TwColors.primary,
                      ),
                      const SizedBox(width: TwSpacing.x3),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Enter promo code',
                            hintStyle: TwText.textXs().copyWith(
                              color: TwColors.textMuted,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text('Apply', style: TwText.link()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: TwSpacing.x5),
                OutlinedCard(
                  backgroundColor: TwColors.cardMuted,
                  borderColor: Colors.transparent,
                  borderRadius: 12,
                  child: const SummaryRow(
                    label: 'Total',
                    value: 'NGN 16,950',
                    isBold: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TwSpacing.x8),
          OutlinedCard(
            backgroundColor: Colors.white,
            borderRadius: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SectionTitle('Delivery Address', fontSize: 18),
                    TextButton(
                      onPressed: () {},
                      child: Text('Change', style: TwText.link()),
                    ),
                  ],
                ),
                const SizedBox(height: TwSpacing.x4),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: TwColors.primary),
                    const SizedBox(width: TwSpacing.x4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Home', style: TwText.fontBoldSm()),
                          Text(
                            '123 Lekki Street, Lagos',
                            style: TwText.textSm(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: TwSpacing.x8),
          OutlinedCard(
            backgroundColor: Colors.white,
            borderRadius: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Payment Method', fontSize: 18),
                const SizedBox(height: TwSpacing.x5),
                for (final option in _paymentOptions) ...[
                  _PaymentOptionTile(
                    title: option.title,
                    subtitle: option.subtitle,
                    isSelected:
                        _paymentOptions.indexOf(option) == _selectedPayment,
                    onTap: () => setState(
                      () => _selectedPayment = _paymentOptions.indexOf(option),
                    ),
                  ),
                  if (option != _paymentOptions.last)
                    const SizedBox(height: TwSpacing.x4),
                ],
              ],
            ),
          ),
          const SizedBox(height: TwSpacing.x8),
          GradientActionButton(label: 'Complete Order', onPressed: () {}),
          const SizedBox(height: TwSpacing.x8),
        ],
      ),
    );
  }
}

class _CheckoutItemRow extends StatelessWidget {
  const _CheckoutItemRow({required this.item});

  final _CheckoutItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: TwText.fontBoldSm()),
              Text('x${item.quantity}', style: TwText.textSm()),
            ],
          ),
        ),
        Text(
          item.price,
          style: TwText.fontBoldSm().copyWith(color: TwColors.primary),
        ),
      ],
    );
  }
}

class _PaymentOptionTile extends StatelessWidget {
  const _PaymentOptionTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(TwSpacing.x4),
        decoration: BoxDecoration(
          color: isSelected ? TwColors.primaryAccent : TwColors.cardMuted,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: TwColors.primary, width: 2)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? TwColors.primary : TwColors.textMuted,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: TwColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: TwSpacing.x4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TwText.fontBoldSm().copyWith(
                      color: isSelected ? Colors.white : TwColors.text,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TwText.textXs().copyWith(
                      color: isSelected ? Colors.white70 : TwColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutItem {
  const _CheckoutItem({
    required this.name,
    required this.price,
    required this.quantity,
  });

  final String name;
  final String price;
  final int quantity;
}

class _PaymentChoice {
  const _PaymentChoice({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}
