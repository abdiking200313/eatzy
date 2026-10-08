import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../app/service_module.dart';
import '../../../config/theme.dart';
import '../../../platform/activity/presentation/activity_controller.dart';
import '../../../platform/cache/catalog_queries.dart';
import '../../../platform/discovery/store_listing.dart';
import 'widgets/home_header.dart';
import 'widgets/popular_stores_section.dart';
import 'widgets/promo_banner.dart';
import 'widgets/recent_activity_section.dart';
import 'widgets/section_header.dart';
import 'widgets/service_grid.dart';

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
  late Stream<List<StoreListing>> _stores;

  /// The cached listing shown on the first frame, before [_stores] emits.
  List<StoreListing>? _initialStores;

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  void _loadStores() {
    final loader = widget.storeListingLoader;
    if (loader != null) {
      _stores = Stream.fromFuture(loader());
    } else {
      final query = CatalogQueries.homeStores();
      _initialStores = query.peek();
      _stores = query.watch();
    }
  }

  void _retryStores() => setState(_loadStores);

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
          HomeHeader(
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
                PromoBanner(onExplore: () => context.go(AppRoutes.explore)),
                SectionHeader(
                  title: 'Categories',
                  actionLabel: 'See all',
                  onPressed: () => context.push(AppRoutes.services),
                ),
                ServiceGrid(
                  modules: ServiceRegistry.modules,
                  onMore: () => context.push(AppRoutes.services),
                ),
                SectionHeader(
                  title: 'Popular Stores',
                  actionLabel: 'View all',
                  onPressed: () => context.go(AppRoutes.explore),
                ),
              ],
            ),
          ),
          PopularStoresSection(
            stream: _stores,
            initialData: _initialStores,
            onRetry: _retryStores,
          ),
          RecentActivitySection(controller: controller),
        ],
      ),
    );
  }
}
