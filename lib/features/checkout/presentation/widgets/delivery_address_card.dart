import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import '../../../../widgets/app_misc.dart';
import '../../../../widgets/app_scaffold.dart';

class DeliveryAddressCard extends StatelessWidget {
  const DeliveryAddressCard({super.key, required this.onChangePressed});

  final VoidCallback onChangePressed;

  @override
  Widget build(BuildContext context) {
    // White card only — the service accent is confined to the icon chip.
    return OutlinedCard(
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
          const SizedBox(height: TwSpacing.rhythmDefault),
          Row(
            children: [
              const ServiceIconChip(icon: Icons.location_on_outlined),
              const SizedBox(width: TwSpacing.rhythmDefault),
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
