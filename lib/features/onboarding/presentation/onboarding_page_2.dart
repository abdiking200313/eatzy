import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../widgets/app_cards.dart';
import 'widgets/onboarding_page.dart';

/// Screen 2 of the redesigned onboarding flow (issue #233): "Order In A Few
/// Taps" — a single order-summary card. Sample/placeholder content for the
/// mockup, not real order data.
class OnboardingPage2 extends StatelessWidget {
  const OnboardingPage2({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingPage(
      title: 'Order In A Few Taps',
      description:
          'Saved addresses and favourites, so a repeat order takes seconds.',
      content: _OrderSummaryCard(),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard();

  static const List<_LineItem> _items = [
    _LineItem(index: 1, name: 'Ayam penyet set', price: '\$6.40'),
    _LineItem(index: 2, name: 'Iced lemon tea', price: '\$3.20'),
  ];

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ayam Penyet Ria',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TwText.fontBoldBase,
                ),
              ),
              const SizedBox(width: TwSpacing.x2),
              Text(
                'Bangsar',
                style: TwText.textSm.copyWith(color: TwColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: TwSpacing.x4),
          const Divider(),
          const SizedBox(height: TwSpacing.x3),
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0) const SizedBox(height: TwSpacing.x3),
            _LineItemRow(item: _items[i]),
          ],
          const SizedBox(height: TwSpacing.x3),
          const Divider(),
          const SizedBox(height: TwSpacing.x3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total incl. delivery',
                style: TwText.textSm.copyWith(color: TwColors.textMuted),
              ),
              Text('\$11.60', style: TwText.fontBoldBase),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineItemRow extends StatelessWidget {
  const _LineItemRow({required this.item});

  final _LineItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: TwColors.primarySoft,
          ),
          child: Text(
            '${item.index}',
            style: TwText.textXs.copyWith(
              color: TwColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: TwSpacing.x3),
        Expanded(
          child: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TwText.textBase,
          ),
        ),
        const SizedBox(width: TwSpacing.x2),
        Text(item.price, style: TwText.fontBoldSm),
      ],
    );
  }
}

class _LineItem {
  const _LineItem({
    required this.index,
    required this.name,
    required this.price,
  });

  final int index;
  final String name;
  final String price;
}
