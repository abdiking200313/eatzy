import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/app_misc.dart';
import '../widgets/app_scaffold.dart';

class AddressesScreenFull extends StatelessWidget {
  const AddressesScreenFull({super.key});

  static const List<_SavedAddress> _addresses = [
    _SavedAddress(
      label: 'Home',
      address: '123 Main Street, Apt 4B\nDowntown, New York, NY 10001',
      isDefault: true,
    ),
    _SavedAddress(
      label: 'Work',
      address: '456 Business Avenue, Suite 800\nFinancial District, New York, NY 10004',
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
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GradientActionButton(
              label: 'Add New Address',
              onPressed: () {},
              icon: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final address in _addresses) ...[
              _AddressCard(address: address),
              if (address != _addresses.last)
                const SizedBox(height: AppSpacing.md),
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
      borderColor:
          address.isDefault ? AppColors.primary : AppColors.outlineVariant,
      borderWidth: address.isDefault ? 2 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(address.label, style: AppTextStyles.cardTitle()),
              if (address.isDefault)
                const StatusPill(
                  label: 'Default',
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.onPrimaryContainer,
                  fontSize: 11,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            address.address,
            style: AppTextStyles.bodySecondary().copyWith(height: 1.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: address.isDefault
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color:
                              AppColors.primaryContainer.withOpacityValue(0.3),
                          border: Border.all(color: AppColors.primary),
                          borderRadius:
                              BorderRadius.circular(AppRadii.lg),
                        ),
                        child: Center(
                          child: Text(
                            'Default Address',
                            style: AppTextStyles.labelBold().copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      )
                    : OutlinedCard(
                        onTap: () {},
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        backgroundColor: Colors.transparent,
                        borderColor: AppColors.outline,
                        child: Center(
                          child: Text(
                            'Set as Default',
                            style: AppTextStyles.labelBold().copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedCard(
                onTap: () {},
                padding: const EdgeInsets.all(AppSpacing.sm),
                backgroundColor: Colors.transparent,
                borderColor: AppColors.outline,
                child: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedCard(
                onTap: () {},
                padding: const EdgeInsets.all(AppSpacing.sm),
                backgroundColor: Colors.transparent,
                borderColor: AppColors.error,
                child: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
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
