import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_routes.dart';
import '../../../app/service_module.dart';
import '../../../config/theme.dart';
import '../../../platform/activity/models/activity_item.dart';
import '../../../platform/activity/presentation/activity_controller.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_scaffold.dart';
import '../data/food_repository.dart';
import '../models/food_models.dart';
import 'cart_controller.dart';
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

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isSubmitting = false;
  String? _submissionError;

  @override
  Widget build(BuildContext context) {
    final controller = widget.cartController ?? CartController.instance;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => AppScaffold(
        title: 'Checkout',
        showBackButton: true,
        body: controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : controller.isEmpty
            ? const _EmptyCheckout()
            : ListView(
                padding: const EdgeInsets.all(TwSpacing.x5),
                children: [
                  OrderSummaryCard(
                    items: controller.items,
                    subtotal: controller.subtotal,
                    tax: controller.tax,
                    deliveryFee: controller.deliveryFee,
                    total: controller.total,
                  ),
                  const SizedBox(height: TwSpacing.x8),
                  DeliveryAddressCard(
                    onChangePressed: () => context.push(AppRoutes.addresses),
                  ),
                  const SizedBox(height: TwSpacing.x8),
                  if (_submissionError case final error?) ...[
                    Text(
                      error,
                      style: TwText.textSm().copyWith(color: TwColors.error),
                    ),
                    const SizedBox(height: TwSpacing.x3),
                  ],
                  GradientActionButton(
                    label: _isSubmitting
                        ? 'Saving order...'
                        : 'Place demo order',
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () => _placeOrder(context, controller),
                  ),
                  const SizedBox(height: TwSpacing.x8),
                ],
              ),
      ),
    );
  }

  Future<void> _placeOrder(
    BuildContext context,
    CartController controller,
  ) async {
    final restaurantId = controller.restaurantId;
    if (restaurantId == null || controller.items.isEmpty) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });
    try {
      final repository =
          widget.orderRepository ??
          SupabaseFoodOrderRepository(client: Supabase.instance.client);
      final orderId = await repository.placeOrder(
        FoodOrderRequest(
          restaurantId: restaurantId,
          items: [
            for (final item in controller.items)
              FoodOrderLineInput(
                menuItemId: item.menuItemId,
                quantity: item.quantity,
              ),
          ],
        ),
      );
      (widget.activityController ?? ActivityController.instance).record(
        ActivityItem(
          id: orderId,
          serviceId: ServiceId.food,
          title: controller.restaurantName ?? 'Food order',
          subtitle: 'Demo order • Somalia',
          status: 'Confirmed',
          occurredAt: DateTime.now(),
          amount: controller.total,
          detailsRoute: AppRoutes.food,
        ),
      );
      await controller.clear();
      if (context.mounted) {
        context.go(AppRoutes.activity);
      }
    } on Object {
      if (mounted) {
        setState(() {
          _submissionError =
              'The food order could not be saved. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
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
            Icon(
              Icons.remove_shopping_cart_outlined,
              size: 52,
              color: context.serviceColors.accent,
            ),
            const SizedBox(height: TwSpacing.x4),
            Text('Your cart is empty', style: TwText.textXl()),
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
