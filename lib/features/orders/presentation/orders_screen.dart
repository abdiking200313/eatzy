import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../widgets/app_scaffold.dart';
import '../models/order.dart';
import 'widgets/order_card.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const List<Order> _activeOrders = [
    Order(
      id: '1000',
      vendor: 'Pizza Palace',
      amount: 'USD 25.99',
      status: 'In Progress',
      isActive: true,
    ),
    Order(
      id: '1001',
      vendor: 'Pizza Palace',
      amount: 'USD 30.99',
      status: 'In Progress',
      isActive: true,
    ),
    Order(
      id: '1002',
      vendor: 'Pizza Palace',
      amount: 'USD 35.99',
      status: 'In Progress',
      isActive: true,
    ),
  ];

  static const List<Order> _completedOrders = [
    Order(
      id: '2000',
      vendor: 'Burger House',
      amount: 'USD 30.99',
      status: 'Delivered',
    ),
    Order(
      id: '2001',
      vendor: 'Burger House',
      amount: 'USD 38.99',
      status: 'Delivered',
    ),
    Order(
      id: '2002',
      vendor: 'Burger House',
      amount: 'USD 46.99',
      status: 'Delivered',
    ),
    Order(
      id: '2003',
      vendor: 'Burger House',
      amount: 'USD 54.99',
      status: 'Delivered',
    ),
    Order(
      id: '2004',
      vendor: 'Burger House',
      amount: 'USD 62.99',
      status: 'Delivered',
    ),
  ];

  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final selectedOrders = _selectedTabIndex == 0
        ? _activeOrders
        : _completedOrders;

    return AppScaffold(
      title: 'Orders',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TwSpacing.x4),
            child: Row(
              children: [
                Expanded(
                  child: _OrdersTab(
                    label: 'Active',
                    isSelected: _selectedTabIndex == 0,
                    onTap: () => setState(() => _selectedTabIndex = 0),
                  ),
                ),
                Expanded(
                  child: _OrdersTab(
                    label: 'Completed',
                    isSelected: _selectedTabIndex == 1,
                    onTap: () => setState(() => _selectedTabIndex = 1),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(TwSpacing.x4),
              itemCount: selectedOrders.length,
              separatorBuilder: (_, _) => const SizedBox(height: TwSpacing.x4),
              itemBuilder: (context, index) =>
                  OrderCard(order: selectedOrders[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: TwSpacing.x4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? TwColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TwText.fontBoldSm().copyWith(
              color: isSelected ? TwColors.primary : TwColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
