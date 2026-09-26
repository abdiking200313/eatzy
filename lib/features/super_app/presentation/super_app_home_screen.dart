import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../app/service_module.dart';
import '../../../config/theme.dart';
import '../../../platform/activity/models/activity_item.dart';
import '../../../platform/activity/presentation/activity_controller.dart';
import '../../../platform/cache/catalog_queries.dart';
import '../../../platform/discovery/store_listing.dart';
import '../../../platform/localization/app_money.dart';
import '../../../widgets/app_misc.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_search_bar.dart';

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
  late final Stream<List<StoreListing>> _stores;

  /// The cached listing shown on the first frame, before [_stores] emits.
  List<StoreListing>? _initialStores;

  @override
  void initState() {
    super.initState();
    final loader = widget.storeListingLoader;
    if (loader != null) {
      _stores = Stream.fromFuture(loader());
    } else {
      final query = CatalogQueries.homeStores();
      _initialStores = query.peek();
      _stores = query.watch();
    }
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
        padding: const EdgeInsets.only(bottom: TwSpacing.x6),
        children: [
          _HomeHeader(
            onSearch: () => context.go(AppRoutes.explore),
            onNotifications: () {},
            onSettings: () => context.push(AppRoutes.settings),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TwSpacing.screenX,
              TwSpacing.x5,
              TwSpacing.screenX,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PromoBanner(onExplore: () => context.go(AppRoutes.explore)),
                _SectionHeader(
                  title: 'Categories',
                  actionLabel: 'See all',
                  onPressed: () => context.push(AppRoutes.services),
                ),
                _ServiceGrid(
                  modules: ServiceRegistry.modules,
                  onMore: () => context.push(AppRoutes.services),
                ),
                _SectionHeader(
                  title: 'Popular Stores',
                  actionLabel: 'View all',
                  onPressed: () => context.go(AppRoutes.explore),
                ),
              ],
            ),
          ),
          _PopularStores(stream: _stores, initialData: _initialStores),
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
              padding: const EdgeInsets.symmetric(
                horizontal: TwSpacing.screenX,
              ),
              child: _SectionHeader(
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
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(TwRadius.hero),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TwSpacing.x5,
            TwSpacing.x2_5,
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
                  const SizedBox(width: TwSpacing.iconButtonGap),
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
              // 18: literal per the "1a" spec's search-field-below-top-bar gap
              // (no token at this value).
              const SizedBox(height: 18),
              AppSearchBar(
                hintText: 'Search restaurants, stores...',
                onTap: onSearch,
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
      // A wide, shallow card (~176 tall at default text scale) rather than
      // the previous content-hugging block, so the banner reads as a
      // distinct promo/discount strip instead of another text section. A
      // minimum rather than a fixed height so it can still grow to fit
      // larger text scales instead of overflowing.
      constraints: const BoxConstraints(minHeight: 176),
      child: Container(
        width: double.infinity,
        // 22: literal per the "1a" spec's hero-banner inner padding (no
        // token at this value).
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: TwColors.primaryGradient,
          borderRadius: BorderRadius.circular(TwRadius.hero),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                // spaceBetween (not center): title top-left, CTA bottom-left
                // per the "1a" spec, now that the banner is taller.
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

/// Category section: a three-column grid of photo tiles, the live service
/// modules then a trailing "More" tile that opens the full Services list
/// (which is also where the coming-soon categories are listed).
class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({required this.modules, required this.onMore});

  final List<ServiceDescriptor> modules;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      // Without an explicit padding a vertical GridView adds the phone's
      // safe-area insets (status bar / home indicator) around itself.
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: modules.length + 1,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: TwSpacing.gridGap,
        mainAxisSpacing: TwSpacing.gridGap,
      ),
      itemBuilder: (context, index) {
        if (index < modules.length) {
          final module = modules[index];
          return _CategoryTile(
            tileKey: Key('service-${module.slug}'),
            icon: module.icon,
            photoUrl: module.photoUrl,
            label: module.title,
            // `go`, not `push`: module.entryRoute belongs to its own shell
            // branch (see app_router.dart), so this switches branches within
            // the persistent bottom-nav shell instead of stacking a
            // full-screen route over it and hiding the nav bar (issue #67).
            onTap: () => context.go(module.entryRoute),
          );
        }
        return _CategoryTile(
          tileKey: const Key('service-more'),
          icon: Icons.grid_view_rounded,
          label: 'More',
          onTap: onMore,
        );
      },
    );
  }
}

/// A square category tile: the service photo fills the whole tile with the
/// label bottom-left in white over a dark fade. Without a photo (or when it
/// fails to load) it falls back to a large icon on a light neutral tile.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.tileKey,
    required this.icon,
    this.photoUrl,
    required this.label,
    required this.onTap,
  });

  /// Applied to the tile's [Material], which tests inspect directly.
  final Key tileKey;
  final IconData icon;
  final String? photoUrl;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    return Semantics(
      label: label,
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        key: tileKey,
        color: TwColors.stone100,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TwRadius.tile),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url == null)
              _IconTileContent(icon: icon, label: label)
            else
              _PhotoTileContent(imageUrl: url, icon: icon, label: label),
            Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoTileContent extends StatelessWidget {
  const _PhotoTileContent({
    required this.imageUrl,
    required this.icon,
    required this.label,
  });

  final String imageUrl;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // The label and fade below are drawn whether or not the photo has
        // loaded, so a slow or failed load never leaves a blank tile.
        LayoutBuilder(
          builder: (context, constraints) {
            final dpr = MediaQuery.devicePixelRatioOf(context);
            return CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              memCacheWidth: (constraints.maxWidth * dpr).round(),
              placeholder: (context, url) => const SizedBox.shrink(),
              errorWidget: (context, url, error) => Align(
                alignment: const Alignment(0, -0.3),
                child: Icon(icon, size: 28, color: TwColors.slate700),
              ),
            );
          },
        ),
        // Darkens only the bottom of the photo so the white label stays
        // readable on any image.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.45, 1],
              colors: [
                TwColors.slate900.withOpacityValue(0),
                TwColors.slate900.withOpacityValue(0.65),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(TwSpacing.x2_5),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: _TileLabel(label: label, color: TwColors.white),
          ),
        ),
      ],
    );
  }
}

class _IconTileContent extends StatelessWidget {
  const _IconTileContent({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TwSpacing.x2_5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: TwColors.slate700),
          const Spacer(),
          _TileLabel(label: label, color: TwColors.text),
        ],
      ),
    );
  }
}

class _TileLabel extends StatelessWidget {
  const _TileLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Shrinks a long label ("Electronics") on narrow tiles or at a large
    // text scale rather than ellipsizing or wrapping it.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.bottomLeft,
      child: Text(
        label,
        maxLines: 1,
        style: TwText.fontBoldSm.copyWith(fontSize: 14, color: color),
      ),
    );
  }
}

class _PopularStores extends StatelessWidget {
  const _PopularStores({required this.stream, this.initialData});

  final Stream<List<StoreListing>> stream;
  final List<StoreListing>? initialData;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StoreListing>>(
      stream: stream,
      initialData: initialData,
      builder: (context, snapshot) {
        // Cached stores count as data even while a refresh is in flight, so
        // the spinner only shows when there is nothing cached at all.
        if (!snapshot.hasData && !snapshot.hasError) {
          return const SizedBox(
            height: 204,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final stores = snapshot.data ?? const <StoreListing>[];
        if (snapshot.hasError || stores.isEmpty) {
          return const SizedBox.shrink();
        }
        // No fixed height: the row takes its tallest card's height, so the
        // cards grow with the text scale instead of overflowing.
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: TwSpacing.screenX),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: TwSpacing.carouselGap,
            children: [
              for (final store in stores.take(6))
                SizedBox(
                  width: 212,
                  child: StoreListCard(
                    name: store.name,
                    subtitle: store.subtitle,
                    imageUrl: store.imageUrl,
                    accentColor: ServiceThemes.forId(store.serviceId).accent,
                    onTap: () => context.push(store.route),
                  ),
                ),
            ],
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

  /// Tap height of the action link.
  static const double _tapHeight = 44;

  @override
  Widget build(BuildContext context) {
    // The gaps above and below are measured from the title text. The link
    // is taller than the title (44px tap area), so the part of it that
    // sticks out past the title is taken out of those gaps instead of
    // being added to them.
    const style = TwText.sectionTitle;
    final titleHeight =
        MediaQuery.textScalerOf(context).scale(style.fontSize!) * style.height!;
    final overhang = ((_tapHeight - titleHeight) / 2).clamp(
      0.0,
      TwSpacing.headerToContent,
    );
    return Padding(
      padding: EdgeInsets.only(
        top: TwSpacing.sectionGap - overhang,
        bottom: TwSpacing.headerToContent - overhang,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              minimumSize: const Size(_tapHeight, _tapHeight),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
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
