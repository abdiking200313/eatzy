import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../platform/localization/app_money.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_scaffold.dart';
import '../models/grocery_models.dart';
import 'grocery_controller.dart';

class GroceryCheckoutScreen extends StatefulWidget {
  const GroceryCheckoutScreen({super.key, this.controller});

  final GroceryController? controller;

  @override
  State<GroceryCheckoutScreen> createState() => _GroceryCheckoutScreenState();
}

class _GroceryCheckoutScreenState extends State<GroceryCheckoutScreen> {
  final _recipientController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _districtController = TextEditingController();
  final _cityController = TextEditingController(text: 'Mogadishu');

  GroceryDeliverySlot? _slot;
  GrocerySubstitutionPreference? _substitutionPreference;
  List<String> _errors = const [];

  GroceryController get _controller =>
      widget.controller ?? GroceryController.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.loadDeliverySlots());
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => AppScaffold(
        title: 'Grocery checkout',
        showBackButton: true,
        body: _controller.isEmpty
            ? _EmptyCheckout(onBrowse: () => context.go(AppRoutes.grocery))
            : _checkoutBody(),
        bottomNavigationBar: _controller.isEmpty
            ? null
            : SafeArea(
                minimum: const EdgeInsets.all(TwSpacing.x4),
                child: GradientActionButton(
                  label:
                      'Confirm demo order • ${AppMoney.format(_controller.total)}',
                  onPressed: _confirm,
                  icon: const Icon(
                    Icons.check_circle_outline,
                    color: TwColors.onPrimary,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _checkoutBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        TwSpacing.x5,
        TwSpacing.x2,
        TwSpacing.x5,
        TwSpacing.x8,
      ),
      children: [
        OutlinedCard(
          backgroundColor: TwColors.errorSoft,
          borderColor: TwColors.error,
          child: Text(
            'Demo checkout only. No payment is taken and no real grocery '
            'order is sent to a store.',
            style: TwText.fontBoldSm.copyWith(color: TwColors.error),
          ),
        ),
        const SizedBox(height: TwSpacing.x6),
        const SectionTitle('Delivery address'),
        const SizedBox(height: TwSpacing.x3),
        TextField(
          controller: _recipientController,
          decoration: const InputDecoration(
            labelText: 'Recipient name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: TwSpacing.x3),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: '+252 …',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: TwSpacing.x3),
        TextField(
          controller: _streetController,
          decoration: const InputDecoration(
            labelText: 'Street or landmark',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: TwSpacing.x3),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _districtController,
                decoration: const InputDecoration(
                  labelText: 'District',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: TwSpacing.x3),
            Expanded(
              child: TextField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: TwSpacing.x3),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.flag_outlined),
          title: Text('Somalia'),
          subtitle: Text('The MVP is configured for delivery in Somalia.'),
        ),
        const SizedBox(height: TwSpacing.x6),
        const SectionTitle('Delivery slot'),
        const SizedBox(height: TwSpacing.x3),
        RadioGroup<GroceryDeliverySlot>(
          groupValue: _slot,
          onChanged: (value) => setState(() => _slot = value),
          child: Column(
            children: [
              for (final slot in _controller.availableDeliverySlots)
                RadioListTile<GroceryDeliverySlot>(
                  contentPadding: EdgeInsets.zero,
                  value: slot,
                  title: Text(slot.label, style: TwText.fontBoldSm),
                  subtitle: Text(slot.detail),
                ),
            ],
          ),
        ),
        const SizedBox(height: TwSpacing.x6),
        const SectionTitle('If an item becomes unavailable'),
        const SizedBox(height: TwSpacing.x2),
        Text('Choose one option before confirming.', style: TwText.textSm),
        RadioGroup<GrocerySubstitutionPreference>(
          groupValue: _substitutionPreference,
          onChanged: (value) {
            setState(() => _substitutionPreference = value);
          },
          child: Column(
            children: [
              for (final preference in GrocerySubstitutionPreference.values)
                RadioListTile<GrocerySubstitutionPreference>(
                  contentPadding: EdgeInsets.zero,
                  value: preference,
                  title: Text(preference.label, style: TwText.fontBoldSm),
                  subtitle: Text(preference.description),
                ),
            ],
          ),
        ),
        if (_errors.isNotEmpty) ...[
          const SizedBox(height: TwSpacing.x4),
          OutlinedCard(
            backgroundColor: TwColors.errorSoft,
            borderColor: TwColors.error,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please complete the following:',
                  style: TwText.fontBoldSm.copyWith(color: TwColors.error),
                ),
                const SizedBox(height: TwSpacing.x2),
                for (final error in _errors)
                  Text(
                    '• $error',
                    style: TwText.textSm.copyWith(color: TwColors.error),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: TwSpacing.x6),
        // White card only — a plain OutlinedCard already uses the neutral
        // fill/border tokens.
        OutlinedCard(
          child: Column(
            children: [
              _SummaryRow(label: 'Subtotal', amount: _controller.subtotal),
              const SizedBox(height: TwSpacing.x2),
              _SummaryRow(label: 'Delivery', amount: _controller.deliveryFee),
              const Divider(height: TwSpacing.x6),
              _SummaryRow(
                label: 'Total (USD)',
                amount: _controller.total,
                emphasized: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    final result = await _controller.confirmOrder(
      address: GroceryDeliveryAddress(
        recipientName: _recipientController.text,
        phone: _phoneController.text,
        street: _streetController.text,
        district: _districtController.text,
        city: _cityController.text,
      ),
      slot: _slot,
      substitutionPreference: _substitutionPreference,
    );
    if (!result.isSuccess) {
      setState(() => _errors = result.errors);
      return;
    }

    setState(() => _errors = const []);
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.check_circle,
          color: TwColors.tertiary,
          size: 44,
        ),
        title: const Text('Order confirmed'),
        content: Text(
          'Your grocery activity was saved in this prototype. '
          'No payment was taken and no order was sent.\n\n'
          'Reference: ${result.confirmation!.orderId}',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (mounted) {
      context.go(AppRoutes.activity);
    }
  }
}

class _EmptyCheckout extends StatelessWidget {
  const _EmptyCheckout({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TwSpacing.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Your grocery cart is empty.', style: TwText.textXl),
            const SizedBox(height: TwSpacing.x5),
            PrimaryButton(
              label: 'Browse groceries',
              fullWidth: false,
              onPressed: onBrowse,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.amount,
    this.emphasized = false,
  });

  final String label;
  final double amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized ? TwText.fontBoldBase : TwText.textSm;
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(AppMoney.format(amount), style: style),
      ],
    );
  }
}
