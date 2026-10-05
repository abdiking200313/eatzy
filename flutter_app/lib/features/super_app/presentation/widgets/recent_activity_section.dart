import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../app/service_module.dart';
import '../../../../config/theme.dart';
import '../../../../platform/activity/models/activity_item.dart';
import '../../../../platform/activity/presentation/activity_controller.dart';
import '../../../../platform/localization/app_money.dart';
import '../../../../widgets/app_misc.dart';
import 'section_header.dart';

/// Scopes the `ActivityController` listener to just the Recent Activity
/// preview so a `record()`/`load()` notification only rebuilds this small
/// subtree, not the rest of the super-app home screen (issue #181).
class RecentActivitySection extends StatelessWidget {
  const RecentActivitySection({super.key, required this.controller});

  final ActivityController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final recentItems = controller.items.take(3).toList(growable: false);
        if (recentItems.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TwSpacing.screenX,
              ),
              child: SectionHeader(
                title: 'Recent Activity',
                actionLabel: 'View all',
                onPressed: () => context.go(AppRoutes.activity),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TwSpacing.screenX,
              ),
              child: _RecentActivityListCard(items: recentItems),
            ),
          ],
        );
      },
    );
  }
}

/// The Recent Activity preview as a single white card containing every
/// row, with internal dividers between rows ("one card per list, not one
/// card per row" — see #21/#27) — mirrors
/// `activity/presentation/activity_screen.dart`'s `_ActivityListCard` so
/// the two activity-feed surfaces stay visually consistent. Per-service
/// accent stays confined to each row's [ServiceIconChip]; the card itself
/// always stays on [TwColors.card].
class _RecentActivityListCard extends StatelessWidget {
  const _RecentActivityListCard({required this.items});

  final List<ActivityItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TwSpacing.x3_5,
          vertical: TwSpacing.x1,
        ),
        child: Column(
          children: [
            for (final item in items) ...[
              _RecentActivityRow(item: item),
              if (item != items.last) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecentActivityRow extends StatelessWidget {
  const _RecentActivityRow({required this.item});

  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final module = ServiceRegistry.byId(item.serviceId);
    final colors = ServiceThemes.forId(item.serviceId);
    final orderDetailsPath = item.orderDetailsPath;
    return InkWell(
      // Same as the Activity tab: open the order details page.
      onTap: orderDetailsPath == null
          ? null
          : () => context.push(orderDetailsPath),
      child: Padding(
        // Horizontal inset comes from the enclosing OutlinedCard's own
        // padding, not repeated here, so the divider between rows spans
        // full width flush with the row content.
        padding: const EdgeInsets.symmetric(vertical: TwSpacing.listRowY),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ServiceIconChip(
              icon: module.icon,
              background: colors.soft,
              foreground: colors.accent,
              size: 42,
              borderRadius: 13,
              iconSize: 20,
            ),
            const SizedBox(width: TwSpacing.x3_5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: TwText.fontBoldSm),
                  // 3: literal per the "1a" spec's title-to-subtitle gap (no
                  // token at this value).
                  const SizedBox(height: 3),
                  StatusPill(
                    label: item.status,
                    backgroundColor: colors.soft,
                    foregroundColor: colors.accent,
                    fontSize: 11,
                  ),
                ],
              ),
            ),
            const SizedBox(width: TwSpacing.x2),
            Text(AppMoney.formatCents(item.amount), style: TwText.fontBoldSm),
          ],
        ),
      ),
    );
  }
}
