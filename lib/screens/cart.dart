import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/app_router.dart';
import '../config/theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/app_misc.dart';
import '../widgets/app_scaffold.dart';

class CartScreenFull extends StatelessWidget {
  const CartScreenFull({super.key});

  static const List<_CartItem> _items = [
    _CartItem(name: 'Chicken Jollof Bowl', price: 'NGN 3,500', quantity: 1),
    _CartItem(name: 'Suya Wrap Combo', price: 'NGN 3,500', quantity: 2),
    _CartItem(name: 'Plantain Chips Pack', price: 'NGN 3,500', quantity: 1),
    _CartItem(name: 'Zobo Cooler', price: 'NGN 3,500', quantity: 1),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'My Cart',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(TwSpacing.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Items in Cart'),
            const SizedBox(height: TwSpacing.x5),
            for (final item in _items) ...[
              _CartItemCard(item: item),
              if (item != _items.last) const SizedBox(height: TwSpacing.x5),
            ],
            const SizedBox(height: TwSpacing.x8),
            OutlinedCard(
              backgroundColor: Colors.white,
              borderRadius: 16,
              child: Column(
                children: const [
                  SummaryRow(label: 'Subtotal', value: 'NGN 14,000'),
                  SizedBox(height: TwSpacing.x5),
                  SummaryRow(label: 'Delivery', value: 'NGN 1,000'),
                  SizedBox(height: TwSpacing.x5),
                  Divider(),
                  SizedBox(height: TwSpacing.x5),
                  SummaryRow(label: 'Total', value: 'NGN 15,000', isBold: true),
                ],
              ),
            ),
            const SizedBox(height: TwSpacing.x8),
            GradientActionButton(
              label: 'Checkout',
              onPressed: () => context.push(AppRoutes.checkout),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({required this.item});

  final _CartItem item;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      backgroundColor: Colors.white,
      borderRadius: 16,
      borderColor: Colors.transparent,
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: TwColors.primaryAccent,
            ),
          ),
          const SizedBox(width: TwSpacing.x5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: TwText.fontBoldBase()),
                const SizedBox(height: TwSpacing.x1),
                Text(
                  '${item.price} x ${item.quantity}',
                  style: TwText.fontBoldSm().copyWith(color: TwColors.primary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: TwColors.primary),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _CartItem {
  const _CartItem({
    required this.name,
    required this.price,
    required this.quantity,
  });

  final String name;
  final String price;
  final int quantity;
}
