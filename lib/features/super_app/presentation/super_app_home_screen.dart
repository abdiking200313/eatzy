import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../app/service_module.dart';
import '../../../config/theme.dart';
import '../../../platform/activity/models/activity_item.dart';
import '../../../platform/activity/presentation/activity_controller.dart';
import '../../../platform/discovery/store_listing.dart';
import '../../../platform/discovery/store_listing_repository.dart';
import '../../../platform/localization/app_money.dart';
import '../../../widgets/app_misc.dart';
import '../../../widgets/app_cards.dart';

class SuperAppHomeScreen extends StatefulWidget {
  const SuperAppHomeScreen({
    super.key,
    this.activityController,
    this.storeListingLoader,
  });

  final ActivityController? activityController;
  final Future<List<StoreListing>> Function()? storeListingLoader;

  @override
  State<SuperAppHomeScreen> createState() => _SuperAppHomeScreenState();
}

class _SuperAppHomeScreenState extends State<SuperAppHomeScreen> {
  late final Future<List<StoreListing>> _storesFuture = _loadStores();

  Future<List<StoreListing>> _loadStores() async {
    final loader =
        widget.storeListingLoader ??
        (() => StoreListingRepository().fetchStores(limit: 10));
    return loader();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.activityController ?? ActivityController.instance;
    // Only the Recent Activity preview below depends on `controller`, so it
    // is the only part of this screen wrapped in a listener (see
    // `CartBadgeAction` for the same narrow-listener pattern). Everything
    // else here builds once per screen build instead of on every
    // ActivityController notification (issue #181).
    return Scaffold(
      backgroundColor: TwColors.bg,
      body: ListView(
        padding: const EdgeInsets.only(bottom: TwSpacing.x8),
        children: [
          _HomeHeader(
            onSearch: () => context.go(AppRoutes.explore),
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
                _PromoBanner(onExplore: () => context.go(AppRoutes.explore)),
                const SizedBox(height: TwSpacing.x8),
                _SectionHeader(
                  title: 'Categories',
                  actionLabel: 'See all',
                  onPressed: () => context.push(AppRoutes.services),
                ),
                const SizedBox(height: TwSpacing.x3),
                _ServiceGrid(
                  modules: ServiceRegistry.modules,
                  comingSoon: ServiceRegistry.comingSoon,
                  onMore: () => context.push(AppRoutes.services),
                ),
                const SizedBox(height: TwSpacing.x8),
                _SectionHeader(
                  title: 'Popular Stores',
                  actionLabel: 'View all',
                  onPressed: () => context.go(AppRoutes.explore),
                ),
                const SizedBox(height: TwSpacing.x3),
              ],
            ),
          ),
          _PopularStores(future: _storesFuture),
          _RecentActivitySection(controller: controller),
        ],
      ),
    );
  }
}

/// Scopes the `ActivityController` listener to just the Recent Activity
/// preview so a `record()`/`load()` notification only rebuilds this small
/// subtree, not the rest of the super-app home screen (issue #181).
class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection({required this.controller});

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
            const SizedBox(height: TwSpacing.x4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: TwSpacing.x5),
              child: _RecentActivityListCard(items: recentItems),
            ),
          ],
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
                      vertical: TwSpacing.x3,
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
    return ConstrainedBox(
      // A wide, shallow card (~132 tall at default text scale) rather than
      // the previous content-hugging block, so the banner reads as a
      // distinct promo/discount strip instead of another text section. A
      // minimum rather than a fixed height so it can still grow to fit
      // larger text scales instead of overflowing.
      constraints: const BoxConstraints(minHeight: 132),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: TwSpacing.x5,
          vertical: TwSpacing.x4,
        ),
        decoration: BoxDecoration(
          gradient: TwColors.primaryGradient,
          borderRadius: BorderRadius.circular(TwRadius.xl),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Everything nearby,\none tap away',
                    style: TwText.textLg.copyWith(
                      color: TwColors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: TwSpacing.x3),
                  OutlinedButton(
                    onPressed: onExplore,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TwColors.white,
                      side: const BorderSide(color: TwColors.white),
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(
                        horizontal: TwSpacing.x4,
                      ),
                    ),
                    child: const Text('Explore'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: TwSpacing.x3),
            // Icon sits in a soft circular badge so it reads as a small
            // illustration rather than a bare glyph floating in the card.
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: TwColors.white.withOpacityValue(0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: TwColors.white,
                size: 34,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Four-column category grid: the live service modules first, then the
/// coming-soon placeholders, then a trailing "More" tile that opens the full
/// Services list.
class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({
    required this.modules,
    required this.comingSoon,
    required this.onMore,
  });

  final List<ServiceDescriptor> modules;
  final List<ComingSoonCategory> comingSoon;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final tileHeight = 92.0 + ((textScale - 1).clamp(0.0, 1.0) * 30.0);
    final platform = ZivoServiceColors.platform;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: modules.length + comingSoon.length + 1,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: TwSpacing.x2,
        mainAxisSpacing: TwSpacing.x2,
        mainAxisExtent: tileHeight,
      ),
      itemBuilder: (context, index) {
        if (index < modules.length) {
          final module = modules[index];
          final colors = ServiceThemes.forSlug(module.slug, module.id);
          return _CategoryTile(
            tileKey: Key('service-${module.slug}'),
            icon: module.icon,
            photoUrl: module.photoUrl,
            label: module.title,
            background: colors.soft,
            foreground: colors.accent,
            // `go`, not `push`: module.entryRoute belongs to its own shell
            // branch (see app_router.dart), so this switches branches within
            // the persistent bottom-nav shell instead of stacking a
            // full-screen route over it and hiding the nav bar (issue #67).
            onTap: () => context.go(module.entryRoute),
          );
        }
        final soonIndex = index - modules.length;
        if (soonIndex < comingSoon.length) {
          final category = comingSoon[soonIndex];
          return _CategoryTile(
            tileKey: Key('coming-soon-${category.id}'),
            icon: category.icon,
            photoUrl: category.photoUrl,
            label: category.title,
            background: platform.soft,
            foreground: platform.accent,
            comingSoon: true,
            onTap: () =>
                showCartSnackBar(context, '${category.title} is coming soon'),
          );
        }
        return _CategoryTile(
          tileKey: const Key('service-more'),
          icon: Icons.grid_view_rounded,
          label: 'More',
          background: TwColors.border,
          foreground: TwColors.slate700,
          onTap: onMore,
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.tileKey,
    required this.icon,
    this.photoUrl,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.comingSoon = false,
  });

  /// Applied to the tile's [Material] (its card surface), which tests and
  /// the white-card rule inspect directly.
  final Key tileKey;
  final IconData icon;

  /// When set, shown (via [ServicePhotoChip]) instead of [icon].
  final String? photoUrl;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: comingSoon ? '$label, coming soon' : label,
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        key: tileKey,
        color: TwColors.card,
        elevation: 0.6,
        shadowColor: TwColors.slate900.withOpacityValue(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TwRadius.xl),
          // A neutral warm gray (rather than the app's usual blue-tinted
          // `TwColors.border`) for coming-soon tiles, so the card outline
          // reads as disabled along with the desaturated chip and muted
          // label rather than just the small "Soon" badge.
          side: BorderSide(
            color: comingSoon ? TwColors.stone300 : TwColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            // Stack defaults non-positioned children to topStart; without
            // this the content Padding below (sized to its own content, not
            // stretched) sat pinned to the top of the tile's full height
            // instead of centered in it.
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: TwSpacing.x2,
                  horizontal: TwSpacing.x1,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _MaybeGrayscale(
                      grayscale: comingSoon,
                      child: photoUrl == null
                          ? ServiceIconChip(
                              icon: icon,
                              background: background,
                              foreground: foreground,
                              borderRadius: TwRadius.full,
                            )
                          : ServicePhotoChip(
                              imageUrl: photoUrl!,
                              ringColor: foreground,
                            ),
                    ),
                    const SizedBox(height: TwSpacing.x1),
                    // Four narrow columns: shrink a long label ("Electronics")
                    // to fit its tile rather than ellipsize or wrap it.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: TwText.fontBoldSm.copyWith(
                          fontSize: 12,
                          color: comingSoon ? TwColors.textMuted : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (comingSoon)
                const Positioned(
                  top: TwSpacing.x1,
                  right: TwSpacing.x1,
                  child: _SoonBadge(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Desaturates [child] (the icon/photo chip) when [grayscale] is true, so a
/// coming-soon tile's whole chip reads as disabled rather than just its
/// "Soon" badge.
class _MaybeGrayscale extends StatelessWidget {
  const _MaybeGrayscale({required this.grayscale, required this.child});

  final bool grayscale;
  final Widget child;

  // Standard luminance-weighted saturation-0 matrix.
  static const List<double> _grayscaleMatrix = <double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  @override
  Widget build(BuildContext context) {
    if (!grayscale) {
      return child;
    }
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(_grayscaleMatrix),
      child: child,
    );
  }
}

class _SoonBadge extends StatelessWidget {
  const _SoonBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TwColors.primary,
        borderRadius: BorderRadius.circular(TwRadius.full),
        border: Border.all(color: TwColors.white, width: 1.5),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        child: Text(
          'Soon',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 9,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: TwColors.white,
          ),
        ),
      ),
    );
  }
}

class _PopularStores extends StatelessWidget {
  const _PopularStores({required this.future});

  final Future<List<StoreListing>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StoreListing>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 196,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final stores = snapshot.data ?? const <StoreListing>[];
        if (snapshot.hasError || stores.isEmpty) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: 196,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: TwSpacing.x5),
            child: Row(
              children: [
                for (final store in stores.take(6))
                  Padding(
                    padding: const EdgeInsets.only(right: TwSpacing.x3),
                    child: SizedBox(
                      width: 150,
                      child: StoreListCard(
                        name: store.name,
                        subtitle: store.subtitle,
                        imageUrl: store.imageUrl,
                        accentColor: ServiceThemes.forId(
                          store.serviceId,
                        ).accent,
                        onTap: () => context.push(store.route),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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
          vertical: TwSpacing.x4,
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
                  const SizedBox(height: TwSpacing.x2),
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
