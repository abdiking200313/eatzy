import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import '../../../../widgets/app_scaffold.dart';

class DeliveryAddressCard extends StatelessWidget {
  const DeliveryAddressCard({super.key, required this.onChangePressed});

  final VoidCallback onChangePressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return OutlinedCard(
      backgroundColor: palette.card,
      borderColor: palette.border,
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionTitle('Delivery Address', fontSize: 18),
              TextButton(
                onPressed: onChangePressed,
                child: Text(
                  'Change',
                  style: TwText.link().copyWith(color: palette.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: TwSpacing.x4),
          Row(
            children: [
              Icon(Icons.location_on, color: palette.accent),
              const SizedBox(width: TwSpacing.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Home', style: TwText.fontBoldSm()),
                    Text(
                      'Maka Al-Mukarama Road, Mogadishu',
                      style: TwText.textSm(),
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
