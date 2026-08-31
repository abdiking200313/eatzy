import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../platform/activity/presentation/activity_controller.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_scaffold.dart';
import '../data/food_repository.dart';
import '../models/food_models.dart';
import 'cart_controller.dart';
import 'food_controller.dart';
import 'widgets/delivery_address_card.dart';
import 'widgets/order_summary_card.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    this.cartController,
    this.orderRepository,
    this.activityController,
  });

  final CartController? cartController;
  final FoodOrderRepository? orderRepository;
  final ActivityController? activityController;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

/// Maps [FoodController.addressErrors]' generic validation messages onto
/// the field key each message is about, so each can be shown inline below
/// its own field via `errorText` (matching the pharmacy checkout pattern)
/// without changing the underlying validation rules in [FoodController].
const Map<String, String> _addressFieldErrorMessages = {
  'recipientName': 'Enter the recipient name.',
  'phone': 'Enter a valid phone number.',
  'street': 'Enter a street or landmark.',
  'district': 'Enter a district.',
  'city': 'Enter a city.',
};

Map<String, String> _addressFieldErrors(List<String> errors) {
  return {
    for (final entry in _addressFieldErrorMessages.entries)
      if (errors.contains(entry.value)) entry.key: entry.value,
  };
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _recipientController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _districtController = TextEditingController();
  final _cityController = TextEditingController(text: 'Mogadishu');

  late final CartController _cartController =
      widget.cartController ?? CartController.instance;
  late final FoodController _foodController = FoodController(
    cartController: _cartController,
    orderRepository: widget.orderRepository,
    activityController: widget.activityController,
  );

  @override
  void dispose() {
    _recipientController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _foodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_cartController, _foodController]),
      builder: (context, _) => AppScaffold(
        title: 'Checkout',
        showBackButton: true,
        body: _cartController.isLoading
            ? const Center(child: CircularProgressIndicator())
            : _cartController.isEmpty
            ? const _EmptyCheckout()
            : ListView(
                padding: const EdgeInsets.all(TwSpacing.x5),
                children: [
                  OrderSummaryCard(
                    items: _cartController.items,
                    subtotal: _cartController.subtotal,
                    tax: _cartController.tax,
                    deliveryFee: _cartController.deliveryFee,
                    total: _cartController.total,
                  ),
                  const SizedBox(height: TwSpacing.x8),
                  DeliveryAddressCard(
                    recipientController: _recipientController,
                    phoneController: _phoneController,
                    streetController: _streetController,
                    districtController: _districtController,
                    cityController: _cityController,
                    fieldErrors: _addressFieldErrors(
                      _foodController.addressErrors,
                    ),
                  ),
                  const SizedBox(height: TwSpacing.x8),
                  if (_foodController.submissionError case final error?) ...[
                    Text(
                      error,
                      style: TwText.textSm.copyWith(color: TwColors.error),
                    ),
                    const SizedBox(height: TwSpacing.x3),
                  ],
                  GradientActionButton(
                    label: _foodController.isSubmitting
                        ? 'Saving order...'
                        : 'Place order',
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                    ),
                    onPressed: _foodController.isSubmitting
                        ? null
                        : _placeOrder,
                  ),
                  const SizedBox(height: TwSpacing.x8),
                ],
              ),
      ),
    );
  }

  Future<void> _placeOrder() async {
    final address = FoodDeliveryAddress(
      recipientName: _recipientController.text,
      phone: _phoneController.text,
      street: _streetController.text,
      district: _districtController.text,
      city: _cityController.text,
    );
    final result = await _foodController.confirmOrder(address);
    if (result.isSuccess && mounted) {
      context.go(AppRoutes.activity);
    }
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
              size: 52,
              color: TwColors.textMuted,
            ),
            const SizedBox(height: TwSpacing.x4),
            Text('Your cart is empty', style: TwText.textXl),
            const SizedBox(height: TwSpacing.x4),
            TextButton(
              onPressed: () => context.go(AppRoutes.mainApp),
              child: const Text('Browse restaurants'),
            ),
          ],
        ),
      ),
    );
  }
}
