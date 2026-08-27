import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/service_module.dart';
import '../../../config/theme.dart';
import '../../../widgets/app_misc.dart';
import '../../../widgets/app_scaffold.dart';
import '../../localization/app_money.dart';
import '../models/activity_item.dart';
import 'activity_controller.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key, this.controller, this.title = 'Activity'});

  final ActivityController? controller;
  final String title;

  @override
  Widget build(BuildContext context) {
    final activityController = controller ?? ActivityController.instance;

    return AppScaffold(
      title: title,
      body: AnimatedBuilder(
        animation: activityController,
        builder: (context, _) {
          final items = activityController.items;
          if (activityController.isLoading && items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (activityController.loadError case final error?
              when items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(TwSpacing.x8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error, textAlign: TextAlign.center),
                    const SizedBox(height: TwSpacing.x4),
                    FilledButton(
                      onPressed: activityController.load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (items.isEmpty) {
            return const _EmptyActivity();
          }

          return ListView(
            padding: const EdgeInsets.all(TwSpacing.x5),
            children: [_ActivityListCard(items: items)],
          );
        },
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(TwSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              color: TwColors.textMuted,
              size: 48,
            ),
            SizedBox(height: TwSpacing.x3),
            Text(
              'No activity yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: TwSpacing.x2),
            Text(
              'Your orders and bookings will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: TwColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// The activity feed as a single white card containing every record, with
/// internal dividers between rows ("one card per list, not one card per
/// row" — see #21/#27). Per-service accent stays confined to each row's
/// [ServiceIconChip]; the card itself always stays on [TwColors.card].
class _ActivityListCard extends StatelessWidget {
  const _ActivityListCard({required this.items});

  final List<ActivityItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final item in items) ...[
            _ActivityRow(item: item),
            if (item != items.last) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final module = ServiceRegistry.byId(item.serviceId);
    final colors = ServiceThemes.forId(item.serviceId);
    return InkWell(
      // `go`, not `push` — detailsRoute is always a service vertical's shell
      // branch root (see app_router.dart); switch to it within the shell
      // instead of stacking a route over the nav bar (issue #67).
      onTap: item.detailsRoute.isEmpty
          ? null
          : () => context.go(item.detailsRoute),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TwSpacing.x4,
          vertical: TwSpacing.rhythmDefault,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ServiceIconChip(
              icon: module.icon,
              background: colors.soft,
              foreground: colors.accent,
            ),
            const SizedBox(width: TwSpacing.x4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: TwText.fontBoldSm()),
                  const SizedBox(height: TwSpacing.rhythmTight),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: TwSpacing.x2,
                    runSpacing: TwSpacing.rhythmTight,
                    children: [
                      if (item.subtitle?.isNotEmpty == true)
                        Text(
                          item.subtitle!,
                          style: TwText.textXs().copyWith(
                            color: TwColors.textMuted,
                          ),
                        ),
                      StatusPill(
                        label: item.status,
                        backgroundColor: colors.soft,
                        foregroundColor: colors.accent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: TwSpacing.x2),
            Text(
              AppMoney.format(item.amount),
              style: TwText.fontBoldSm().copyWith(color: colors.accent),
            ),
          ],
        ),
      ),
    );
  }
}
