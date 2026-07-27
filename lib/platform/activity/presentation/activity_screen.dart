import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/service_module.dart';
import '../../../config/theme.dart';
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

          return ListView.separated(
            padding: const EdgeInsets.all(TwSpacing.x5),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: TwSpacing.x3),
            itemBuilder: (context, index) => _ActivityCard(item: items[index]),
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

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.item});

  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final module = ServiceRegistry.byId(item.serviceId);
    final colors = ServiceThemes.forId(item.serviceId);
    return Card(
      color: colors.card,
      elevation: 0.6,
      shadowColor: TwColors.slate900.withOpacityValue(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TwRadius.xl),
        side: BorderSide(color: colors.border),
      ),
      child: ListTile(
        onTap: item.detailsRoute.isEmpty
            ? null
            : () => context.push(item.detailsRoute),
        leading: CircleAvatar(
          backgroundColor: colors.soft,
          foregroundColor: colors.accent,
          child: Icon(module.icon),
        ),
        title: Text(item.title, style: TwText.fontBoldSm()),
        subtitle: Text(
          [
            if (item.subtitle?.isNotEmpty == true) item.subtitle!,
            item.status,
          ].join(' • '),
        ),
        trailing: Text(
          AppMoney.format(item.amount),
          style: TwText.fontBoldSm().copyWith(color: colors.accent),
        ),
      ),
    );
  }
}
