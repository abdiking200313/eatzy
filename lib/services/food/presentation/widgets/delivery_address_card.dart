import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import '../../../../widgets/app_scaffold.dart';

/// Rounded outline border matching the app-wide input style (see
/// `AppTextField` and the global `InputDecorationTheme` in
/// `config/tailwind.dart`), instead of the sharp Material default corners.
final _addressFieldBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(TwRadius.xl),
);

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
    // White card only — the service accent is confined to the icon chip.
    return OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Delivery Address', fontSize: 18),
          const SizedBox(height: TwSpacing.x2),
          Text(
            'Delivery is currently available in Somalia only.',
            style: TwText.textSm,
          ),
          const SizedBox(height: TwSpacing.x4),
          TextField(
            key: const ValueKey('food-recipient-name'),
            controller: recipientController,
            decoration: InputDecoration(
              labelText: 'Recipient name',
              prefixIcon: const Icon(Icons.person_outline),
              border: _addressFieldBorder,
            ),
          ),
          const SizedBox(height: TwSpacing.x3),
          TextField(
            key: const ValueKey('food-phone'),
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone number',
              hintText: '+252 …',
              prefixIcon: const Icon(Icons.phone_outlined),
              border: _addressFieldBorder,
            ),
          ),
          const SizedBox(height: TwSpacing.x3),
          TextField(
            key: const ValueKey('food-street'),
            controller: streetController,
            decoration: InputDecoration(
              labelText: 'Street or landmark',
              prefixIcon: const Icon(Icons.home_outlined),
              border: _addressFieldBorder,
            ),
          ),
          const SizedBox(height: TwSpacing.x3),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('food-district'),
                  controller: districtController,
                  decoration: InputDecoration(
                    labelText: 'District',
                    border: _addressFieldBorder,
                  ),
                ),
              ),
              const SizedBox(width: TwSpacing.x3),
              Expanded(
                child: TextField(
                  key: const ValueKey('food-city'),
                  controller: cityController,
                  decoration: InputDecoration(
                    labelText: 'City',
                    border: _addressFieldBorder,
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
                      style: TwText.textSm.copyWith(color: TwColors.error),
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
