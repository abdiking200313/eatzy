import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import '../../../../widgets/app_misc.dart';
import '../../models/order.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order});

  final Order order;

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
              Text('Order #${order.id}', style: TwText.fontBoldBase()),
              StatusPill(
                label: order.status,
                backgroundColor: isActive
                    ? TwColors.primaryAccent
                    : TwColors.secondary.withOpacityValue(0.2),
                foregroundColor: isActive
                    ? TwColors.blue900
                    : TwColors.secondary,
                fontSize: 11,
              ),
            ],
          ),
          const SizedBox(height: TwSpacing.x3),
          Text(order.vendor, style: TwText.textSm()),
          const SizedBox(height: TwSpacing.x1),
          Text(
            order.amount,
            style: TwText.text2xl().copyWith(
              fontSize: 18,
              color: isActive ? TwColors.primary : TwColors.text,
            ),
          ),
          const SizedBox(height: TwSpacing.x4),
          if (isActive)
            PrimaryButton(
              label: 'Track Order',
              onPressed: () => context.push(AppRoutes.trackOrder),
            )
          else
            OutlinedCard(
              onTap: () => context.push(AppRoutes.checkout),
              padding: const EdgeInsets.symmetric(vertical: TwSpacing.x3),
              backgroundColor: Colors.transparent,
              borderColor: TwColors.primary,
              child: Center(
                child: Text(
                  'Reorder',
                  style: TwText.fontBoldSm().copyWith(color: TwColors.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
