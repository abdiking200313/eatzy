import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/app_router.dart';
import '../config/theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/app_misc.dart';
import '../widgets/app_scaffold.dart';

class OrdersScreenFull extends StatefulWidget {
  const OrdersScreenFull({super.key});

  @override
  State<OrdersScreenFull> createState() => _OrdersScreenFullState();
}

class _OrdersScreenFullState extends State<OrdersScreenFull> {
  static const List<_Order> _activeOrders = [
    _Order(
      id: '1000',
      vendor: 'Pizza Palace',
      amount: 'USD 25.99',
      status: 'In Progress',
      isActive: true,
    ),
    _Order(
      id: '1001',
      vendor: 'Pizza Palace',
      amount: 'USD 30.99',
      status: 'In Progress',
      isActive: true,
    ),
    _Order(
      id: '1002',
      vendor: 'Pizza Palace',
      amount: 'USD 35.99',
      status: 'In Progress',
      isActive: true,
    ),
  ];

  static const List<_Order> _completedOrders = [
    _Order(
      id: '2000',
      vendor: 'Burger House',
      amount: 'USD 30.99',
      status: 'Delivered',
    ),
    _Order(
      id: '2001',
      vendor: 'Burger House',
      amount: 'USD 38.99',
      status: 'Delivered',
    ),
    _Order(
      id: '2002',
      vendor: 'Burger House',
      amount: 'USD 46.99',
      status: 'Delivered',
    ),
    _Order(
      id: '2003',
      vendor: 'Burger House',
      amount: 'USD 54.99',
      status: 'Delivered',
    ),
    _Order(
      id: '2004',
      vendor: 'Burger House',
      amount: 'USD 62.99',
      status: 'Delivered',
    ),
  ];

  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final selectedOrders =
        _selectedTabIndex == 0 ? _activeOrders : _completedOrders;

    return AppScaffold(
      title: 'Orders',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: selectedOrders.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) => _OrderCard(
                order: selectedOrders[index],
              ),
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
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.labelBold().copyWith(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final _Order order;

  @override
  Widget build(BuildContext context) {
    final isActive = order.isActive;

    return OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order #${order.id}', style: AppTextStyles.cardTitle()),
              StatusPill(
                label: order.status,
                backgroundColor: isActive
                    ? AppColors.primaryContainer
                    : AppColors.secondary.withOpacityValue(0.2),
                foregroundColor: isActive
                    ? AppColors.onPrimaryContainer
                    : AppColors.secondary,
                fontSize: 11,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(order.vendor, style: AppTextStyles.bodySecondary()),
          const SizedBox(height: AppSpacing.xs),
          Text(
            order.amount,
            style: AppTextStyles.h3().copyWith(
              fontSize: 18,
              color: isActive ? AppColors.primary : AppColors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (isActive)
            PrimaryButton(
              label: 'Track Order',
              onPressed: () => context.push(AppRoutes.trackOrder),
            )
          else
            OutlinedCard(
              onTap: () => context.push(AppRoutes.checkout),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              backgroundColor: Colors.transparent,
              borderColor: AppColors.primary,
              child: Center(
                child: Text(
                  'Reorder',
                  style: AppTextStyles.labelBold().copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Order {
  const _Order({
    required this.id,
    required this.vendor,
    required this.amount,
    required this.status,
    this.isActive = false,
  });

  final String id;
  final String vendor;
  final String amount;
  final String status;
  final bool isActive;
}
