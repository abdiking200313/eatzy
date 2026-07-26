import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/app_misc.dart';
import '../widgets/app_scaffold.dart';

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

  static const List<_SavedAddress> _addresses = [
    _SavedAddress(
      label: 'Home',
      address: '123 Main Street, Apt 4B\nDowntown, New York, NY 10001',
      isDefault: true,
    ),
    _SavedAddress(
      label: 'Work',
      address:
          '456 Business Avenue, Suite 800\nFinancial District, New York, NY 10004',
    ),
    _SavedAddress(
      label: 'Mom\'s Place',
      address: '789 Residential Lane\nUptown, New York, NY 10023',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Saved Addresses',
      showBackButton: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(TwSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GradientActionButton(
              label: 'Add New Address',
              onPressed: () {},
              icon: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
            const SizedBox(height: TwSpacing.x5),
            for (final address in _addresses) ...[
              _AddressCard(address: address),
              if (address != _addresses.last)
                const SizedBox(height: TwSpacing.x4),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address});

  final _SavedAddress address;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      borderColor: address.isDefault ? TwColors.primary : TwColors.borderStrong,
      borderWidth: address.isDefault ? 2 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(address.label, style: TwText.fontBoldBase()),
              if (address.isDefault)
                const StatusPill(
                  label: 'Default',
                  backgroundColor: TwColors.primaryAccent,
                  foregroundColor: TwColors.blue900,
                  fontSize: 11,
                ),
            ],
          ),
          const SizedBox(height: TwSpacing.x3),
          Text(address.address, style: TwText.textSm().copyWith(height: 1.5)),
          const SizedBox(height: TwSpacing.x4),
          Row(
            children: [
              Expanded(
                child: address.isDefault
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: TwSpacing.x3,
                        ),
                        decoration: BoxDecoration(
                          color: TwColors.primaryAccent.withOpacityValue(0.3),
                          border: Border.all(color: TwColors.primary),
                          borderRadius: BorderRadius.circular(TwRadius.lg),
                        ),
                        child: Center(
                          child: Text(
                            'Default Address',
                            style: TwText.fontBoldSm().copyWith(
                              color: TwColors.primary,
                            ),
                          ),
                        ),
                      )
                    : OutlinedCard(
                        onTap: () {},
                        padding: const EdgeInsets.symmetric(
                          vertical: TwSpacing.x3,
                        ),
                        backgroundColor: Colors.transparent,
                        borderColor: TwColors.textMuted,
                        child: Center(
                          child: Text(
                            'Set as Default',
                            style: TwText.fontBoldSm().copyWith(
                              color: TwColors.textMuted,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: TwSpacing.x3),
              OutlinedCard(
                onTap: () {},
                padding: const EdgeInsets.all(TwSpacing.x3),
                backgroundColor: Colors.transparent,
                borderColor: TwColors.textMuted,
                child: const Icon(
                  Icons.edit_outlined,
                  color: TwColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: TwSpacing.x3),
              OutlinedCard(
                onTap: () {},
                padding: const EdgeInsets.all(TwSpacing.x3),
                backgroundColor: Colors.transparent,
                borderColor: TwColors.error,
                child: const Icon(
                  Icons.delete_outline,
                  color: TwColors.error,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SavedAddress {
  const _SavedAddress({
    required this.label,
    required this.address,
    this.isDefault = false,
  });

  final String label;
  final String address;
  final bool isDefault;
}
