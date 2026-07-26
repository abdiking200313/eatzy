import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import '../../../../widgets/app_scaffold.dart';
import '../../models/checkout_models.dart';

class PaymentMethodCard extends StatelessWidget {
  const PaymentMethodCard({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<PaymentChoice> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      backgroundColor: Colors.white,
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Payment Method', fontSize: 18),
          const SizedBox(height: TwSpacing.x5),
          for (var index = 0; index < options.length; index++) ...[
            _PaymentOptionTile(
              option: options[index],
              isSelected: index == selectedIndex,
              onTap: () => onSelected(index),
            ),
            if (index != options.length - 1)
              const SizedBox(height: TwSpacing.x4),
          ],
        ],
      ),
    );
  }
}

class _PaymentOptionTile extends StatelessWidget {
  const _PaymentOptionTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final PaymentChoice option;
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
                    option.title,
                    style: TwText.fontBoldSm().copyWith(
                      color: isSelected ? Colors.white : TwColors.text,
                    ),
                  ),
                  Text(
                    option.subtitle,
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
