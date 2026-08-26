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
        padding: const EdgeInsets.all(TwSpacing.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {},
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'Add New Address',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: TwSpacing.x2),
                    Icon(Icons.add_rounded, size: 19),
                  ],
                ),
              ),
            ),
            const SizedBox(height: TwSpacing.rhythmSection),
            OutlinedCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final address in _addresses) ...[
                    _AddressRow(address: address),
                    if (address != _addresses.last) const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address});

  final _SavedAddress address;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TwSpacing.x4,
        vertical: TwSpacing.rhythmDefault,
      ),
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
          const SizedBox(height: TwSpacing.rhythmTight),
          Text(address.address, style: TwText.textSm().copyWith(height: 1.5)),
          const SizedBox(height: TwSpacing.rhythmDefault),
          Row(
            children: [
              Expanded(
                child: address.isDefault
                    ? OutlinedButton(
                        onPressed: null,
                        child: const Text(
                          'Default Address',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : OutlinedButton(
                        onPressed: () {},
                        child: const Text(
                          'Set as Default',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
