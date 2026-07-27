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
      address: 'Maka Al-Mukarama Road\nHodan, Mogadishu, Somalia',
      isDefault: true,
    ),
    _SavedAddress(
      label: 'Work',
      address: 'Airport Road\nWadajir, Mogadishu, Somalia',
    ),
    _SavedAddress(
      label: 'Family',
      address: 'Taleex Road\nHodan, Mogadishu, Somalia',
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
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {},
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Add New Address'),
                    SizedBox(width: TwSpacing.x2),
                    Icon(Icons.add_rounded, size: 19),
                  ],
                ),
              ),
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
    final palette = context.serviceColors;
    final colorScheme = Theme.of(context).colorScheme;
    return OutlinedCard(
      padding: const EdgeInsets.all(TwSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(address.label, style: TwText.fontBoldBase()),
              if (address.isDefault)
                StatusPill(
                  label: 'Default',
                  backgroundColor: palette.soft,
                  foregroundColor: palette.accent,
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
                          color: palette.soft,
                          border: Border.all(color: palette.border),
                          borderRadius: BorderRadius.circular(TwRadius.lg),
                        ),
                        child: Center(
                          child: Text(
                            'Default Address',
                            style: TwText.fontBoldSm().copyWith(
                              color: palette.accent,
                            ),
                          ),
                        ),
                      )
                    : OutlinedButton(
                        onPressed: () {},
                        child: const Text('Set as Default'),
                      ),
              ),
              const SizedBox(width: TwSpacing.x3),
              IconButton.outlined(
                tooltip: 'Edit ${address.label}',
                onPressed: () {},
                color: palette.accent,
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
              const SizedBox(width: TwSpacing.x2),
              IconButton.outlined(
                tooltip: 'Delete ${address.label}',
                onPressed: () {},
                color: colorScheme.error,
                icon: const Icon(Icons.delete_outline, size: 18),
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
