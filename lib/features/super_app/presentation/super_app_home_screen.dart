import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_routes.dart';
import '../../../app/service_module.dart';
import '../../../config/theme.dart';
import '../../../services/food/data/restaurant_repository.dart';
import '../../../services/food/models/restaurant.dart';
import '../../../platform/activity/models/activity_item.dart';
import '../../../platform/activity/presentation/activity_controller.dart';
import '../../../platform/localization/app_money.dart';
import '../../../widgets/app_misc.dart';
import '../../../widgets/app_cards.dart';

class SuperAppHomeScreen extends StatefulWidget {
  const SuperAppHomeScreen({
    super.key,
    this.activityController,
    this.restaurantLoader,
  });

  final ActivityController? activityController;
  final Future<List<Restaurant>> Function()? restaurantLoader;

  @override
  State<SuperAppHomeScreen> createState() => _SuperAppHomeScreenState();
}

class _SuperAppHomeScreenState extends State<SuperAppHomeScreen> {
  late final Future<List<Restaurant>> _restaurantsFuture = _loadRestaurants();

  Future<List<Restaurant>> _loadRestaurants() async {
    final loader =
        widget.restaurantLoader ?? RestaurantRepository().fetchRestaurants;
    return loader();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.activityController ?? ActivityController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final recentItems = controller.items.take(3).toList(growable: false);
        return Scaffold(
          backgroundColor: TwColors.bg,
          body: ListView(
            padding: const EdgeInsets.only(bottom: TwSpacing.x8),
            children: [
              _HomeHeader(
                onSearch: () => context.push(AppRoutes.foodExplore),
                onNotifications: () {},
                onSettings: () => context.push(AppRoutes.settings),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TwSpacing.x5,
                  TwSpacing.x5,
                  TwSpacing.x5,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Good morning', style: TwText.text2xl),
                    const SizedBox(height: TwSpacing.x1),
                    Text(
                      DateFormat('EEEE, MMMM d').format(DateTime.now()),
                      style: TwText.textSm,
                    ),
                    const SizedBox(height: TwSpacing.x6),
                    _PromoBanner(
                      onExplore: () => context.push(AppRoutes.foodExplore),
                    ),
                    const SizedBox(height: TwSpacing.x8),
                    _SectionHeader(
                      title: 'Categories',
                      actionLabel: 'See all',
                      onPressed: () => context.push(AppRoutes.services),
                    ),
                    const SizedBox(height: TwSpacing.x3),
                    _ServiceGrid(modules: ServiceRegistry.modules),
                    const SizedBox(height: TwSpacing.x8),
                    _SectionHeader(
                      title: 'Popular Restaurants',
                      actionLabel: 'View all',
                      onPressed: () => context.push(AppRoutes.foodExplore),
                    ),
                    const SizedBox(height: TwSpacing.x3),
                  ],
                ),
              ),
              _PopularRestaurants(future: _restaurantsFuture),
              if (recentItems.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TwSpacing.x5,
                    TwSpacing.x8,
                    TwSpacing.x5,
                    0,
                  ),
                  child: _SectionHeader(
                    title: 'Recent Activity',
                    actionLabel: 'View all',
                    onPressed: () => context.go(AppRoutes.activity),
                  ),
                ),
                const SizedBox(height: TwSpacing.x3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: TwSpacing.x5),
                  child: _RecentActivityListCard(items: recentItems),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.onSearch,
    required this.onNotifications,
    required this.onSettings,
  });

  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: TwColors.primaryGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TwSpacing.x5,
            TwSpacing.x3,
            TwSpacing.x3,
            TwSpacing.x6,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'zivo',
                    style: TwText.textXl.copyWith(
                      color: TwColors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: onNotifications,
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: TwColors.white,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: onSettings,
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: TwColors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TwSpacing.x2),
              Material(
                color: TwColors.white,
                borderRadius: BorderRadius.circular(TwRadius.full),
                child: InkWell(
                  borderRadius: BorderRadius.circular(TwRadius.full),
                  onTap: onSearch,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: TwSpacing.x4,
                      vertical: TwSpacing.x4,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: TwColors.textMuted),
                        SizedBox(width: TwSpacing.x3),
                        Expanded(
                          child: Text(
                            'Search restaurants, stores...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: TwColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TwSpacing.x5),
      decoration: BoxDecoration(
        gradient: TwColors.primaryGradient,
        borderRadius: BorderRadius.circular(TwRadius.xl),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Everything nearby,\none tap away',
                  style: TwText.textLg.copyWith(
                    color: TwColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: TwSpacing.x3),
                OutlinedButton(
                  onPressed: onExplore,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: TwColors.white,
                    side: const BorderSide(color: TwColors.white),
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(
                      horizontal: TwSpacing.x4,
                    ),
                  ),
                  child: const Text('Explore'),
                ),
              ],
            ),
          ),
          const SizedBox(width: TwSpacing.x2),
          const Icon(Icons.storefront_rounded, color: TwColors.white, size: 52),
        ],
      ),
    );
  }
}

class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({required this.modules});

  final List<ServiceDescriptor> modules;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final tileHeight = 92.0 + ((textScale - 1).clamp(0.0, 1.0) * 30.0);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: modules.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: TwSpacing.x3,
        mainAxisSpacing: TwSpacing.x3,
        mainAxisExtent: tileHeight,
      ),
      itemBuilder: (context, index) => _ServiceTile(module: modules[index]),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.module});

  final ServiceDescriptor module;

  @override
  Widget build(BuildContext context) {
    final colors = ServiceThemes.forId(module.id);
    return Material(
      key: Key('service-${module.id.name}'),
      color: TwColors.card,
      elevation: 0.6,
      shadowColor: TwColors.slate900.withOpacityValue(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TwRadius.xl),
        side: const BorderSide(color: TwColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // `go`, not `push`: module.entryRoute belongs to its own shell
        // branch (see app_router.dart), so this switches branches within
        // the persistent bottom-nav shell instead of stacking a full-screen
        // route over it and hiding the nav bar (issue #67).
        onTap: () => context.go(module.entryRoute),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: TwSpacing.x2,
            horizontal: TwSpacing.x1,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ServiceIconChip(
                icon: module.icon,
                background: colors.soft,
                foreground: colors.accent,
                borderRadius: TwRadius.full,
              ),
              const SizedBox(height: TwSpacing.x1),
              Text(
                module.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TwText.fontBoldSm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopularRestaurants extends StatelessWidget {
  const _PopularRestaurants({required this.future});

  final Future<List<Restaurant>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Restaurant>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 172,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final restaurants = snapshot.data ?? const <Restaurant>[];
        if (snapshot.hasError || restaurants.isEmpty) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: 172,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: TwSpacing.x5),
            child: Row(
              children: [
                for (final restaurant in restaurants.take(6))
                  Padding(
                    padding: const EdgeInsets.only(right: TwSpacing.x3),
                    child: _PopularRestaurantCard(restaurant: restaurant),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PopularRestaurantCard extends StatelessWidget {
  const _PopularRestaurantCard({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final logoUrl = restaurant.logoUrl.trim();
    // Decode at roughly the rendered 140x88 box (the card's fixed width
    // and image height) scaled for device pixel density. Capped at 3x
    // since a wider cap buys no visible sharpness on a thumbnail this
    // small while still inflating decode memory.
    final cacheScale = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
    final cacheWidth = (140 * cacheScale).round();
    final cacheHeight = (88 * cacheScale).round();
    return SizedBox(
      width: 140,
      child: OutlinedCard(
        padding: EdgeInsets.zero,
        borderRadius: TwRadius.xl,
        onTap: () => context.push(AppRoutes.restaurantDetails(restaurant.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(TwRadius.xl),
              ),
              child: SizedBox(
                height: 88,
                width: double.infinity,
                child: logoUrl.isEmpty
                    ? const ColoredBox(
                        color: TwColors.primarySoft,
                        child: Icon(
                          Icons.storefront_outlined,
                          color: TwColors.primary,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: logoUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: cacheWidth,
                        memCacheHeight: cacheHeight,
                        errorWidget: (_, _, _) => const ColoredBox(
                          color: TwColors.primarySoft,
                          child: Icon(
                            Icons.storefront_outlined,
                            color: TwColors.primary,
                          ),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(TwSpacing.x2),
              child: Text(
                restaurant.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TwText.fontBoldSm,
              ),
            ),
          ],
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
        Expanded(child: Text(title, style: TwText.sectionLabel)),
        TextButton(onPressed: onPressed, child: Text(actionLabel)),
      ],
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
      child: Column(
        children: [
          for (final item in items) ...[
            _RecentActivityRow(item: item),
            if (item != items.last) const Divider(height: 1),
          ],
        ],
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
    return InkWell(
      // `go`, not `push` — detailsRoute is always a service vertical's
      // shell branch root (see app_router.dart); switch to it within the
      // shell instead of stacking a route over the nav bar (issue #67).
      onTap: item.detailsRoute.isEmpty
          ? null
          : () => context.go(item.detailsRoute),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TwSpacing.x3,
          vertical: TwSpacing.rhythmTight,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ServiceIconChip(
              icon: module.icon,
              background: colors.soft,
              foreground: colors.accent,
              iconSize: 20,
            ),
            const SizedBox(width: TwSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: TwText.fontBoldSm),
                  const SizedBox(height: TwSpacing.rhythmTight),
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
            Text(AppMoney.format(item.amount), style: TwText.fontBoldSm),
          ],
        ),
      ),
    );
  }
}
