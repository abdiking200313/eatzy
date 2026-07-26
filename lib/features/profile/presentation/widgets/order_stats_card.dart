import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import '../models/profile_models.dart';

class OrderStatsCard extends StatelessWidget {
  const OrderStatsCard({super.key, required this.stats});

  final List<ProfileStat> stats;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      backgroundColor: Colors.white,
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Orders', style: TwText.fontBoldBase()),
          const SizedBox(height: TwSpacing.x5),
          Row(
            children: [
              for (final stat in stats)
                Expanded(child: _OrderStatItem(stat: stat)),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderStatItem extends StatelessWidget {
  const _OrderStatItem({required this.stat});

  final ProfileStat stat;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: stat.route == null ? null : () => context.push(stat.route!),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: TwSpacing.x1),
        child: Column(
          children: [
            Icon(stat.icon, color: TwColors.primary, size: 30),
            const SizedBox(height: 10),
            Text(
              stat.title,
              style: TwText.fontBoldBase(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(stat.count, style: TwText.textSm()),
          ],
        ),
      ),
    );
  }
}
