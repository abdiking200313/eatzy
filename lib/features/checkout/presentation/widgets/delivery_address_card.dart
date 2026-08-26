import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import '../../../../widgets/app_scaffold.dart';

/// Collects a real delivery address for a food order, mirroring the inline
/// address-collection pattern used by grocery and pharmacy checkout (see
/// `GroceryCheckoutScreen` / `PharmacyCheckoutScreen`) instead of only
/// displaying static placeholder text.
class DeliveryAddressCard extends StatelessWidget {
  const DeliveryAddressCard({
    super.key,
    required this.recipientController,
    required this.phoneController,
    required this.streetController,
    required this.districtController,
    required this.cityController,
    this.errors = const [],
  });

  final TextEditingController recipientController;
  final TextEditingController phoneController;
  final TextEditingController streetController;
  final TextEditingController districtController;
  final TextEditingController cityController;
  final List<String> errors;

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
          const SectionTitle('Delivery Address', fontSize: 18),
          const SizedBox(height: TwSpacing.x2),
          Text(
            'Delivery is currently available in Somalia only.',
            style: TwText.textSm(),
          ),
          const SizedBox(height: TwSpacing.x4),
          TextField(
            key: const ValueKey('food-recipient-name'),
            controller: recipientController,
            decoration: const InputDecoration(
              labelText: 'Recipient name',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: TwSpacing.x3),
          TextField(
            key: const ValueKey('food-phone'),
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '+252 …',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: TwSpacing.x3),
          TextField(
            key: const ValueKey('food-street'),
            controller: streetController,
            decoration: const InputDecoration(
              labelText: 'Street or landmark',
              prefixIcon: Icon(Icons.home_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: TwSpacing.x3),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('food-district'),
                  controller: districtController,
                  decoration: const InputDecoration(
                    labelText: 'District',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: TwSpacing.x3),
              Expanded(
                child: TextField(
                  key: const ValueKey('food-city'),
                  controller: cityController,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          if (errors.isNotEmpty) ...[
            const SizedBox(height: TwSpacing.x3),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final error in errors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: TwSpacing.x1),
                    child: Text(
                      '• $error',
                      style: TwText.textSm().copyWith(color: TwColors.error),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
