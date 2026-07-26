import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_scaffold.dart';
import '../models/checkout_models.dart';
import 'widgets/delivery_address_card.dart';
import 'widgets/order_summary_card.dart';
import 'widgets/payment_method_card.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const List<CheckoutItem> _items = [
    CheckoutItem(name: 'Jollof Rice', price: 'NGN 2,500', quantity: 2),
    CheckoutItem(name: 'Grilled Chicken', price: 'NGN 4,500', quantity: 1),
    CheckoutItem(name: 'Plantain Chips', price: 'NGN 1,500', quantity: 1),
  ];

  static const List<PaymentChoice> _paymentOptions = [
    PaymentChoice(title: 'Credit Card', subtitle: 'Visa ending in 4242'),
    PaymentChoice(title: 'Digital Wallet', subtitle: 'Google Pay'),
    PaymentChoice(title: 'Cash', subtitle: 'Pay on delivery'),
  ];

  int _selectedPayment = 0;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Checkout',
      showBackButton: true,
      body: ListView(
        padding: const EdgeInsets.all(TwSpacing.x5),
        children: [
          const OrderSummaryCard(items: _items),
          const SizedBox(height: TwSpacing.x8),
          DeliveryAddressCard(onChangePressed: () {}),
          const SizedBox(height: TwSpacing.x8),
          PaymentMethodCard(
            options: _paymentOptions,
            selectedIndex: _selectedPayment,
            onSelected: (index) => setState(() => _selectedPayment = index),
          ),
          const SizedBox(height: TwSpacing.x8),
          GradientActionButton(label: 'Complete Order', onPressed: () {}),
          const SizedBox(height: TwSpacing.x8),
        ],
      ),
    );
  }
}
