import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_misc.dart';
import '../../../widgets/store_hero_app_bar.dart';
import '../data/food_repository.dart';
import '../data/restaurant_menu_repository.dart';
import '../models/cart_item.dart';
import '../models/food_models.dart';
import '../models/restaurant_menu.dart';
import 'cart_controller.dart';
import 'widgets/menu_item_card.dart';

typedef RestaurantMenuLoader =
    Future<RestaurantMenu> Function(String restaurantId);

/// Fixed height of the pinned category-chip bar (`_CategoryHeaderDelegate`'s
/// `minExtent`/`maxExtent`) — shared with `_RestaurantScreenState`'s
/// scroll-position math so the two stay in sync. Sized for the sticky chip
/// bar's 18-top/12-bottom padding plus a 36px chip.
const _kCategoryHeaderExtent = 72.0;

class RestaurantScreen extends StatefulWidget {
  const RestaurantScreen({
    super.key,
    required this.restaurantId,
    this.menuLoader,
    this.cartController,
    this.locationRepository,
  });

  final String restaurantId;
  final RestaurantMenuLoader? menuLoader;
  final CartController? cartController;
  final RestaurantLocationRepository? locationRepository;

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen> {
  final _sectionKeys = <String, GlobalKey>{};
  final _scrollController = ScrollController();

  late Future<RestaurantMenu> _menuFuture;
  late Future<List<RestaurantLocation>> _locationsFuture;
  String? _selectedCategoryId;

  // The pinned category chip bar sits right below the collapsed app bar
  // (`kToolbarHeight`, since `StoreHeroAppBar` is `pinned: true`) once
  // scrolled past its `expandedHeight` hero. A section counts as "current"
  // once its heading has scrolled up to (or past) that line, matching what
  // a user reading top-to-bottom would call the category they're looking
  // at — not the strict top-of-viewport, which would flip a beat too late.
  double get _sectionThreshold =>
      MediaQuery.of(context).padding.top +
      kToolbarHeight +
      _kCategoryHeaderExtent;

  @override
  void initState() {
    super.initState();
    _menuFuture = _menuLoader(widget.restaurantId);
    _locationsFuture = _loadLocations();
    _scrollController.addListener(_syncSelectedCategoryFromScroll);
  }

  void _syncSelectedCategoryFromScroll() {
    if (_sectionKeys.isEmpty) {
      return;
    }
    final threshold = _sectionThreshold;
    String? currentId;
    for (final entry in _sectionKeys.entries) {
      final renderObject = entry.value.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) {
        continue;
      }
      final top = renderObject.localToGlobal(Offset.zero).dy;
      if (top <= threshold) {
        currentId = entry.key;
      } else {
        break;
      }
    }
    if (currentId != null && currentId != _selectedCategoryId) {
      setState(() => _selectedCategoryId = currentId);
    }
  }

  RestaurantMenuLoader get _menuLoader =>
      widget.menuLoader ?? RestaurantMenuRepository().fetchMenu;

  @override
  void dispose() {
    _scrollController.removeListener(_syncSelectedCategoryFromScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<RestaurantLocation>> _loadLocations() async {
    try {
      final repository =
          widget.locationRepository ??
          SupabaseRestaurantLocationRepository(
            client: Supabase.instance.client,
          );
      return await repository.fetchLocations(widget.restaurantId);
    } on Object {
      return const [];
    }
  }

  @override
  void didUpdateWidget(covariant RestaurantScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restaurantId != widget.restaurantId ||
        oldWidget.menuLoader != widget.menuLoader ||
        oldWidget.locationRepository != widget.locationRepository) {
      _sectionKeys.clear();
      _selectedCategoryId = null;
      _menuFuture = _menuLoader(widget.restaurantId);
      _locationsFuture = _loadLocations();
    }
  }

  void _retry() {
    setState(() {
      _menuFuture = _menuLoader(widget.restaurantId);
      _locationsFuture = _loadLocations();
    });
  }

  void _selectCategory(MenuCategory category) {
    setState(() => _selectedCategoryId = category.id);

    final sectionContext = _sectionKeys[category.id]?.currentContext;
    if (sectionContext != null) {
      Scrollable.ensureVisible(
        sectionContext,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    }
  }

  Future<void> _addToCart(
    RestaurantMenu menu,
    MenuItem menuItem,
    int quantity,
  ) async {
    final controller = widget.cartController ?? CartController.instance;
    final cartItem = CartItem(
      menuItemId: menuItem.id,
      restaurantId: menu.restaurant.id,
      restaurantName: menu.restaurant.name,
      name: menuItem.name,
      unitPrice: menuItem.price,
      imageUrl: menuItem.imageUrl,
    );

    try {
      var result = await controller.addItem(cartItem, quantity: quantity);
      if (!mounted) {
        return;
      }

      if (result == CartAddResult.restaurantConflict) {
        final replaceCart = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Start a new cart?'),
            content: Text(
              'Your cart contains items from '
              '${controller.restaurantName ?? 'another restaurant'}. '
              'Starting a cart from ${menu.restaurant.name} will remove them.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Keep cart'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Start new cart'),
              ),
            ],
          ),
        );

        if (replaceCart != true) {
          return;
        }
        result = await controller.addItem(
          cartItem,
          replaceRestaurantCart: true,
          quantity: quantity,
        );
      }

      if (!mounted) {
        return;
      }
      final itemLabel = quantity > 1
          ? '$quantity× ${menuItem.name}'
          : menuItem.name;
      final message = switch (result) {
        CartAddResult.quantityIncreased => '$itemLabel quantity increased',
        CartAddResult.replacedRestaurant => 'New cart started with $itemLabel',
        CartAddResult.maximumReached =>
          '${menuItem.name} is already at the maximum quantity',
        _ => '$itemLabel added to cart',
      };
      showCartSnackBar(context, message);
    } on Object {
      if (!mounted) {
        return;
      }
      showCartSnackBar(
        context,
        'The item was added, but the cart could not be saved.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<RestaurantMenu>(
        future: _menuFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _RestaurantLoading();
          }

          if (snapshot.hasError) {
            return _RestaurantError(onRetry: _retry);
          }

          return _RestaurantMenuView(
            menu: snapshot.requireData,
            locationsFuture: _locationsFuture,
            selectedCategoryId: _selectedCategoryId,
            scrollController: _scrollController,
            sectionKeyFor: (categoryId) =>
                _sectionKeys.putIfAbsent(categoryId, GlobalKey.new),
            onCategorySelected: _selectCategory,
            onAddToCart: (item, quantity) =>
                _addToCart(snapshot.requireData, item, quantity),
          );
        },
      ),
      floatingActionButton: AnimatedBuilder(
        animation: widget.cartController ?? CartController.instance,
        builder: (context, _) {
          final controller = widget.cartController ?? CartController.instance;
          if (controller.itemCount == 0) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: () => context.push(AppRoutes.foodCart),
            icon: Badge(
              label: Text('${controller.itemCount}'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            label: const Text('View cart'),
          );
        },
      ),
    );
  }
}

class _RestaurantMenuView extends StatelessWidget {
  const _RestaurantMenuView({
    required this.menu,
    required this.locationsFuture,
    required this.selectedCategoryId,
    required this.scrollController,
    required this.sectionKeyFor,
    required this.onCategorySelected,
    required this.onAddToCart,
  });

  final RestaurantMenu menu;
  final Future<List<RestaurantLocation>> locationsFuture;
  final String? selectedCategoryId;
  final ScrollController scrollController;
  final GlobalKey Function(String categoryId) sectionKeyFor;
  final ValueChanged<MenuCategory> onCategorySelected;
  final void Function(MenuItem item, int quantity) onAddToCart;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        StoreHeroAppBar(
          title: menu.restaurant.name,
          imageUrl: menu.restaurant.logoUrl,
          fallbackIcon: Icons.restaurant_rounded,
          imageFit: BoxFit.contain,
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  TwSpacing.screenX,
                  TwSpacing.x6,
                  TwSpacing.screenX,
                  TwSpacing.x5,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(menu.restaurant.name, style: TwText.text2xl),
                    if (menu.restaurant.description.trim().isNotEmpty) ...[
                      const SizedBox(height: TwSpacing.x2),
                      Text(menu.restaurant.description, style: TwText.textSm),
                    ],
                    const SizedBox(height: TwSpacing.x3),
                    Row(
                      children: [
                        Icon(
                          Icons.restaurant_menu_rounded,
                          size: 18,
                          color: context.serviceColors.accent,
                        ),
                        const SizedBox(width: TwSpacing.x2),
                        Text(
                          '${menu.itemCount} items',
                          style: TwText.fontBoldSm,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: TwSpacing.x2,
                          ),
                          child: Text(
                            '•',
                            style: TextStyle(color: TwColors.textMuted),
                          ),
                        ),
                        Text(
                          '${menu.categories.length} categories',
                          style: TwText.textSm,
                        ),
                      ],
                    ),
                    FutureBuilder<List<RestaurantLocation>>(
                      future: locationsFuture,
                      builder: (context, snapshot) {
                        final locations =
                            snapshot.data ?? const <RestaurantLocation>[];
                        if (locations.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: TwSpacing.x3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.storefront_outlined,
                                size: 18,
                                color: context.serviceColors.accent,
                              ),
                              const SizedBox(width: TwSpacing.x2),
                              Expanded(
                                child: Text(
                                  locations
                                      .map((location) => location.storeName)
                                      .join(' • '),
                                  style: TwText.textSm,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (menu.categories.isNotEmpty)
          SliverPersistentHeader(
            pinned: true,
            delegate: _CategoryHeaderDelegate(
              categories: menu.categories,
              selectedCategoryId:
                  selectedCategoryId ?? menu.categories.first.id,
              onSelected: onCategorySelected,
            ),
          ),
        if (menu.categories.isEmpty)
          const SliverFillRemaining(hasScrollBody: false, child: _EmptyMenu())
        else
          for (final category in menu.categories) ...[
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TwSpacing.screenX,
                      TwSpacing.sectionGap,
                      TwSpacing.screenX,
                      TwSpacing.headerToContent,
                    ),
                    child: Row(
                      key: sectionKeyFor(category.id),
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            category.name,
                            style: TwText.sectionTitle,
                          ),
                        ),
                        Text(
                          '${category.items.length} '
                          '${category.items.length == 1 ? 'item' : 'items'}',
                          style: TwText.textXs.copyWith(
                            color: TwColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // A per-category `SliverList.builder` (rather than the whole
            // category folded into one eager `SliverToBoxAdapter`+`Column`)
            // so item cards — and the `CachedNetworkImage` requests they
            // kick off — are only built once they scroll into view. The
            // header above stays an eager `SliverToBoxAdapter` so its
            // `GlobalKey` context is always mounted for the category-chip
            // "jump to section" scroll (`Scrollable.ensureVisible`).
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = category.items[index];
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        TwSpacing.screenX,
                        0,
                        TwSpacing.screenX,
                        index == category.items.length - 1 ? 0 : TwSpacing.x3,
                      ),
                      child: MenuItemCard(
                        item: item,
                        onAddToCart: (quantity) => onAddToCart(item, quantity),
                      ),
                    ),
                  ),
                );
              }, childCount: category.items.length),
            ),
          ],
        const SliverToBoxAdapter(child: SizedBox(height: TwSpacing.x6)),
      ],
    );
  }
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  _CategoryHeaderDelegate({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  final List<MenuCategory> categories;
  final String selectedCategoryId;
  final ValueChanged<MenuCategory> onSelected;

  @override
  double get minExtent => _kCategoryHeaderExtent;

  @override
  double get maxExtent => _kCategoryHeaderExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final palette = context.serviceColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.background,
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: TwColors.slate900.withOpacityValue(20 / 255),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              TwSpacing.screenX,
              18,
              TwSpacing.screenX,
              TwSpacing.x3,
            ),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: TwSpacing.x2),
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = category.id == selectedCategoryId;

              return ChoiceChip(
                showCheckmark: false,
                selected: isSelected,
                selectedColor: palette.accent,
                backgroundColor: palette.soft,
                side: BorderSide(
                  color: isSelected ? palette.accent : palette.border,
                ),
                label: Text(category.name),
                labelStyle: TwText.textXs.copyWith(
                  color: isSelected ? palette.onAccent : palette.accent,
                ),
                onSelected: (_) => onSelected(category),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CategoryHeaderDelegate oldDelegate) =>
      oldDelegate.categories != categories ||
      oldDelegate.selectedCategoryId != selectedCategoryId;
}

class _RestaurantLoading extends StatelessWidget {
  const _RestaurantLoading();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Text('Restaurant'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: TwColors.text,
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: TwSpacing.x4),
                Text('Loading menu…', style: TwText.textSm),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RestaurantError extends StatelessWidget {
  const _RestaurantError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Text('Restaurant'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: TwColors.text,
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(TwSpacing.x5),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: OutlinedCard(
                  backgroundColor: TwColors.card,
                  borderColor: TwColors.border,
                  borderRadius: TwRadius.xl,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        color: palette.accent,
                        size: 42,
                      ),
                      const SizedBox(height: TwSpacing.x3),
                      Text('We could not load this menu', style: TwText.textXl),
                      const SizedBox(height: TwSpacing.x2),
                      Text(
                        'Check your connection and try again.',
                        textAlign: TextAlign.center,
                        style: TwText.textSm,
                      ),
                      const SizedBox(height: TwSpacing.x5),
                      TextButton(
                        onPressed: onRetry,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyMenu extends StatelessWidget {
  const _EmptyMenu();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TwSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 48,
              color: context.serviceColors.accent,
            ),
            const SizedBox(height: TwSpacing.x3),
            Text('No menu items yet', style: TwText.textXl),
            const SizedBox(height: TwSpacing.x2),
            Text(
              'This restaurant has not added any items.',
              textAlign: TextAlign.center,
              style: TwText.textSm,
            ),
          ],
        ),
      ),
    );
  }
}
