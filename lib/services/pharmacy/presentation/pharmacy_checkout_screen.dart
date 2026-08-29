import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../platform/localization/app_money.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_misc.dart';
import '../../../widgets/app_scaffold.dart';
import '../models/pharmacy_checkout.dart';
import 'pharmacy_controller.dart';

class PharmacyCheckoutScreen extends StatefulWidget {
  const PharmacyCheckoutScreen({super.key, this.controller});

  final PharmacyController? controller;

  @override
  State<PharmacyCheckoutScreen> createState() => _PharmacyCheckoutScreenState();
}

class _PharmacyCheckoutScreenState extends State<PharmacyCheckoutScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _cityController;
  late final TextEditingController _districtController;
  late final TextEditingController _addressController;
  late final TextEditingController _instructionsController;

  Map<String, String> _errors = const {};

  PharmacyController get _controller =>
      widget.controller ?? PharmacyController.instance;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _cityController = TextEditingController(text: 'Mogadishu');
    _districtController = TextEditingController();
    _addressController = TextEditingController();
    _instructionsController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _addressController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return AppScaffold(
          title: 'Pharmacy checkout',
          showBackButton: true,
          body: _controller.isCartEmpty
              ? const _EmptyCheckout()
              : ListView(
                  padding: const EdgeInsets.all(TwSpacing.x5),
                  children: [
                    const _DemoNotice(),
                    const SizedBox(height: TwSpacing.x5),
                    Text('Delivery address', style: TwText.textXl),
                    const SizedBox(height: TwSpacing.x3),
                    TextFormField(
                      initialValue: PharmacyCheckoutDetails.country,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Country',
                        prefixIcon: Icon(Icons.public),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: TwSpacing.x3),
                    _CheckoutField(
                      key: const ValueKey('pharmacy-customer-name'),
                      controller: _nameController,
                      label: 'Customer name',
                      icon: Icons.person_outline,
                      errorText: _errors['customerName'],
                    ),
                    const SizedBox(height: TwSpacing.x3),
                    _CheckoutField(
                      key: const ValueKey('pharmacy-phone'),
                      controller: _phoneController,
                      label: 'Phone number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      errorText: _errors['phoneNumber'],
                    ),
                    const SizedBox(height: TwSpacing.x3),
                    _CheckoutField(
                      key: const ValueKey('pharmacy-city'),
                      controller: _cityController,
                      label: 'City',
                      icon: Icons.location_city_outlined,
                      errorText: _errors['city'],
                    ),
                    const SizedBox(height: TwSpacing.x3),
                    _CheckoutField(
                      key: const ValueKey('pharmacy-district'),
                      controller: _districtController,
                      label: 'District',
                      icon: Icons.map_outlined,
                      errorText: _errors['district'],
                    ),
                    const SizedBox(height: TwSpacing.x3),
                    _CheckoutField(
                      key: const ValueKey('pharmacy-address'),
                      controller: _addressController,
                      label: 'Street, building or landmark',
                      icon: Icons.home_outlined,
                      errorText: _errors['addressLine'],
                    ),
                    const SizedBox(height: TwSpacing.x3),
                    _CheckoutField(
                      controller: _instructionsController,
                      label: 'Delivery instructions (optional)',
                      icon: Icons.notes_outlined,
                      maxLines: 3,
                    ),
                    if (_errors['cart'] != null ||
                        _errors['stock'] != null ||
                        _errors['order'] != null) ...[
                      const SizedBox(height: TwSpacing.x3),
                      Text(
                        _errors['cart'] ??
                            _errors['stock'] ??
                            _errors['order']!,
                        style: TwText.textSm.copyWith(color: TwColors.error),
                      ),
                    ],
                    const SizedBox(height: TwSpacing.x5),
                    _CheckoutSummary(controller: _controller),
                    const SizedBox(height: TwSpacing.x5),
                    GradientActionButton(
                      label:
                          'Confirm demo order · '
                          '${AppMoney.format(_controller.total)}',
                      icon: const Icon(Icons.check, color: Colors.white),
                      onPressed: _submit,
                    ),
                    const SizedBox(height: TwSpacing.x8),
                  ],
                ),
        );
      },
    );
  }

  PharmacyCheckoutDetails _details() {
    return PharmacyCheckoutDetails(
      customerName: _nameController.text,
      phoneNumber: _phoneController.text,
      city: _cityController.text,
      district: _districtController.text,
      addressLine: _addressController.text,
      deliveryInstructions: _instructionsController.text,
    );
  }

  Future<void> _submit() async {
    final result = await _controller.placeDemoOrder(_details());
    if (!result.isSuccess) {
      setState(() => _errors = result.validation.errors);
      return;
    }

    setState(() => _errors = const {});
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Demo order confirmed'),
        content: Text(result.message),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.go(AppRoutes.activity);
            },
            child: const Text('View activity'),
          ),
        ],
      ),
    );
  }
}

class _CheckoutField extends StatelessWidget {
  const _CheckoutField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.errorText,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? errorText;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        errorText: errorText,
        border: const OutlineInputBorder(),
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    // White card only — the service accent is confined to the icon chip.
    return OutlinedCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ServiceIconChip(icon: Icons.science_outlined),
          const SizedBox(width: TwSpacing.rhythmDefault),
          Expanded(
            child: Text(
              'Interactive preview only. This confirms a demo OTC order; '
              'no payment is processed and no pharmacy receives it.',
              style: TwText.textSm,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutSummary extends StatelessWidget {
  const _CheckoutSummary({required this.controller});

  final PharmacyController controller;

  @override
  Widget build(BuildContext context) {
    // White card only — a plain OutlinedCard already uses the neutral
    // fill/border tokens.
    return OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order summary', style: TwText.fontBoldBase),
          const SizedBox(height: TwSpacing.x3),
          Text(
            '${controller.itemCount} OTC '
            '${controller.itemCount == 1 ? 'item' : 'items'}',
            style: TwText.textSm,
          ),
          const SizedBox(height: TwSpacing.x2),
          Text(
            'Delivery: ${AppMoney.format(PharmacyController.deliveryFee)}',
            style: TwText.textSm,
          ),
          const Divider(height: TwSpacing.x6),
          Row(
            children: [
              Expanded(child: Text('Total', style: TwText.fontBoldBase)),
              Text(
                AppMoney.format(controller.total),
                style: TwText.fontBoldBase.copyWith(color: TwColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyCheckout extends StatelessWidget {
  const _EmptyCheckout();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TwSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.remove_shopping_cart_outlined,
              color: TwColors.textMuted,
              size: 52,
            ),
            const SizedBox(height: TwSpacing.x4),
            Text('Your pharmacy cart is empty', style: TwText.textXl),
            const SizedBox(height: TwSpacing.x4),
            TextButton(
              onPressed: () => context.go(AppRoutes.pharmacy),
              child: const Text('Browse OTC products'),
            ),
          ],
        ),
      ),
    );
  }
}
