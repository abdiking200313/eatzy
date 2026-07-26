import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import '../../../../widgets/app_scaffold.dart';

class DeliveryAddressCard extends StatelessWidget {
  const DeliveryAddressCard({super.key, required this.onChangePressed});

  final VoidCallback onChangePressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
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
                onPressed: onChangePressed,
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
                    Text('123 Lekki Street, Lagos', style: TwText.textSm()),
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
