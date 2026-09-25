import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../widgets/checkout_view.dart';
import '../../shared/data/idempotency_key.dart';
import '../../shared/models/delivery_details.dart';
import 'pharmacy_controller.dart';

class PharmacyCheckoutScreen extends StatefulWidget {
  const PharmacyCheckoutScreen({super.key, this.controller});

  final PharmacyController? controller;

  @override
  State<PharmacyCheckoutScreen> createState() => _PharmacyCheckoutScreenState();
}

class _PharmacyCheckoutScreenState extends State<PharmacyCheckoutScreen> {
  final _noteController = TextEditingController();

  Map<String, String> _errors = const {};

  /// Identifies this checkout attempt (issue #59): generated once when this
  /// screen is first built and reused for every retry on this same visit,
  /// so a lost response followed by a retry collapses into the original
  /// order server-side instead of creating a duplicate. A fresh visit to
  /// checkout (a new instance of this screen) gets a fresh key.
  final String _idempotencyKey = generateIdempotencyKey();

  PharmacyController get _controller =>
      widget.controller ?? PharmacyController.instance;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CheckoutView(
        title: 'Checkout',
        isEmpty: _controller.isCartEmpty,
        emptyMessage: 'Your pharmacy cart is empty',
        browseLabel: 'Browse OTC products',
        onBrowse: () => context.go(AppRoutes.pharmacy),
        noteController: _noteController,
        itemLines: [
          for (final item in _controller.cartItems)
            CheckoutLine('${item.product.name} ×${item.quantity}', item.total),
        ],
        feeLines: [
          CheckoutLine('Subtotal', _controller.subtotal),
          const CheckoutLine('Delivery fee', PharmacyController.deliveryFee),
        ],
        total: _controller.total,
        isSubmitting: _controller.isSubmitting,
        errorText: _errors['cart'] ?? _errors['stock'] ?? _errors['order'],
        onSubmit: _submit,
      ),
    );
  }

  Future<void> _submit() async {
    final result = await _controller.placeDemoOrder(
      delivery: DeliveryDetails(note: _noteController.text),
      idempotencyKey: _idempotencyKey,
    );
    if (!mounted) {
      return;
    }
    setState(() => _errors = result.validation.errors);
    if (!result.isSuccess) {
      return;
    }

    await showOrderPlacedDialog(
      context,
      orderId: result.orderId!,
      message: result.message,
    );
    if (mounted) {
      context.go(AppRoutes.activity);
    }
  }
}
