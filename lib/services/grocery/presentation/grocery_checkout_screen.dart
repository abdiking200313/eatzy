import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../widgets/checkout_view.dart';
import '../../shared/data/idempotency_key.dart';
import '../../shared/models/delivery_details.dart';
import '../models/grocery_models.dart';
import 'grocery_controller.dart';

/// Checkout for every grocery-engine store (Grocery, Fresh Meat,
/// Electronics): the shared [CheckoutView] plus grocery's own delivery-slot
/// and substitution-preference sections.
class GroceryCheckoutScreen extends StatefulWidget {
  const GroceryCheckoutScreen({
    super.key,
    this.controller,
    this.storeType = GroceryStoreType.grocery,
  });

  final GroceryController? controller;

  /// Grocery, Fresh Meat and Electronics each have their own cart.
  final GroceryStoreType storeType;

  @override
  State<GroceryCheckoutScreen> createState() => _GroceryCheckoutScreenState();
}

class _GroceryCheckoutScreenState extends State<GroceryCheckoutScreen> {
  static const _slotError = 'Choose a delivery slot.';
  static const _substitutionError = 'Choose a substitution preference.';

  final _noteController = TextEditingController();

  GroceryDeliverySlot? _slot;
  GrocerySubstitutionPreference? _substitutionPreference;
  List<String> _errors = const [];

  /// Identifies this checkout attempt (issue #59): generated once when this
  /// screen is first built and reused for every retry on this same visit,
  /// so a lost response followed by a retry collapses into the original
  /// order server-side instead of creating a duplicate. A fresh visit to
  /// checkout (a new instance of this screen) gets a fresh key.
  final String _idempotencyKey = generateIdempotencyKey();

  GroceryController get _controller =>
      widget.controller ?? GroceryController.forType(widget.storeType);

  @override
  void initState() {
    super.initState();
    unawaited(_controller.loadDeliverySlots());
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// The first error that isn't shown inline under its own section.
  String? get _generalError => _errors
      .where((error) => error != _slotError && error != _substitutionError)
      .firstOrNull;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CheckoutView(
        title: '${widget.storeType.serviceName} checkout',
        isEmpty: _controller.isEmpty,
        emptyMessage: 'Your cart is empty',
        browseLabel: 'Browse stores',
        onBrowse: () => context.go(widget.storeType.listRoute),
        noteController: _noteController,
        itemLines: [
          for (final line in _controller.cart)
            CheckoutLine(
              '${line.product.name} ×${line.quantityLabel}',
              line.total,
            ),
        ],
        feeLines: [
          CheckoutLine('Subtotal', _controller.subtotal),
          CheckoutLine('Delivery fee', _controller.deliveryFee),
        ],
        total: _controller.total,
        isSubmitting: _controller.isSubmitting,
        errorText: _generalError,
        onSubmit: _confirm,
        extraSections: [_slotSection(), _substitutionSection()],
      ),
    );
  }

  Widget _slotSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Delivery slot', style: TwText.sectionTitle),
        const SizedBox(height: TwSpacing.headerToContent),
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
        if (_errors.contains(_slotError))
          Text(
            _slotError,
            style: TwText.textSm.copyWith(color: TwColors.error),
          ),
      ],
    );
  }

  Widget _substitutionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'If an item becomes unavailable',
          style: TwText.sectionTitle,
        ),
        const SizedBox(height: TwSpacing.x2),
        Text('Choose one option before ordering.', style: TwText.textSm),
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
        if (_errors.contains(_substitutionError))
          Text(
            _substitutionError,
            style: TwText.textSm.copyWith(color: TwColors.error),
          ),
      ],
    );
  }

  Future<void> _confirm() async {
    final result = await _controller.confirmOrder(
      delivery: DeliveryDetails(note: _noteController.text),
      slot: _slot,
      substitutionPreference: _substitutionPreference,
      idempotencyKey: _idempotencyKey,
    );
    if (!mounted) {
      return;
    }
    setState(() => _errors = result.errors);
    if (!result.isSuccess) {
      return;
    }

    await showOrderPlacedDialog(context, orderId: result.confirmation!.orderId);
    if (mounted) {
      context.go(AppRoutes.activity);
    }
  }
}
