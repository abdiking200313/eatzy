import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_routes.dart';
import '../../../app/service_module.dart';
import '../../../config/theme.dart';
import '../../../platform/activity/models/activity_item.dart';
import '../../../platform/activity/presentation/activity_controller.dart';
import '../../../platform/localization/app_money.dart';
import '../../../widgets/zivo_logo.dart';

class SuperAppHomeScreen extends StatelessWidget {
  const SuperAppHomeScreen({super.key, this.activityController});

  final ActivityController? activityController;

  @override
  Widget build(BuildContext context) {
    final controller = activityController ?? ActivityController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final recentItems = controller.items.take(3).toList(growable: false);
        return Scaffold(
          appBar: AppBar(
            title: const ZivoLogo(height: 30),
            actions: [
              IconButton(
                tooltip: 'Notifications',
                onPressed: () {},
                icon: const Icon(Icons.notifications_none_rounded),
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: () => context.push(AppRoutes.settings),
                icon: const Icon(Icons.settings_outlined),
              ),
              const SizedBox(width: TwSpacing.x2),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              TwSpacing.x4,
              TwSpacing.x3,
              TwSpacing.x4,
              TwSpacing.x8,
            ),
            children: [
              Text('Good morning', style: TwText.text2xl()),
              const SizedBox(height: TwSpacing.x1),
              Text(
                DateFormat('EEEE, MMMM d').format(DateTime.now()),
                style: TwText.textSm(),
              ),
              const SizedBox(height: TwSpacing.x8),
              Text('Our Services', style: TwText.textXl()),
              const SizedBox(height: TwSpacing.x3),
              _ServiceGrid(modules: ServiceRegistry.modules),
              if (recentItems.isNotEmpty) ...[
                const SizedBox(height: TwSpacing.x8),
                _SectionHeader(
                  title: 'Recent Activity',
                  actionLabel: 'View all',
                  onPressed: () => context.go(AppRoutes.activity),
                ),
                const SizedBox(height: TwSpacing.x3),
                for (var index = 0; index < recentItems.length; index++) ...[
                  _RecentActivityCard(item: recentItems[index]),
                  if (index != recentItems.length - 1)
                    const SizedBox(height: TwSpacing.x2),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({required this.modules});

  final List<ServiceDescriptor> modules;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final cardHeight = 170.0 + ((textScale - 1).clamp(0.0, 1.0) * 54.0);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: modules.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: TwSpacing.x3,
        mainAxisSpacing: TwSpacing.x3,
        mainAxisExtent: cardHeight,
      ),
      itemBuilder: (context, index) => _ServiceCard(module: modules[index]),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.module});

  final ServiceDescriptor module;

  @override
  Widget build(BuildContext context) {
    final colors = ServiceThemes.forId(module.id);
    return Material(
      key: Key('service-${module.id.name}'),
      color: colors.card,
      elevation: 0.8,
      shadowColor: TwColors.slate900.withOpacityValue(0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TwRadius.xl),
        side: BorderSide(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(module.entryRoute),
        child: Padding(
          padding: const EdgeInsets.all(TwSpacing.x3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.soft,
                      borderRadius: BorderRadius.circular(TwRadius.lg),
                    ),
                    child: Icon(module.icon, color: colors.accent, size: 23),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: colors.accent,
                    size: 17,
                  ),
                ],
              ),
              const Spacer(),
              Text(module.title, style: TwText.fontBoldBase()),
              const SizedBox(height: TwSpacing.x1),
              Text(
                module.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TwText.textXs().copyWith(color: TwColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: TwText.textXl())),
        TextButton(onPressed: onPressed, child: Text(actionLabel)),
      ],
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.item});

  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final module = ServiceRegistry.byId(item.serviceId);
    final colors = ServiceThemes.forId(item.serviceId);
    return Material(
      color: TwColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TwRadius.xl),
        side: BorderSide(color: colors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TwSpacing.x3,
          vertical: TwSpacing.x1,
        ),
        onTap: item.detailsRoute.isEmpty
            ? null
            : () => context.push(item.detailsRoute),
        leading: CircleAvatar(
          backgroundColor: colors.soft,
          foregroundColor: colors.accent,
          child: Icon(module.icon, size: 20),
        ),
        title: Text(item.title, style: TwText.fontBoldSm()),
        subtitle: Text(
          item.status,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TwText.textXs(),
        ),
        trailing: Text(
          AppMoney.format(item.amount),
          style: TwText.fontBoldSm().copyWith(color: colors.accent),
        ),
      ),
    );
  }
}
