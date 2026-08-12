import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../features/cart/models/cart_item.dart';
import '../../../features/cart/presentation/cart_controller.dart';
import '../../../services/food/data/food_repository.dart';
import '../../../services/food/models/food_models.dart';
import '../../../widgets/app_cards.dart';
import '../data/restaurant_menu_repository.dart';
import '../models/restaurant_menu.dart';
import 'widgets/menu_item_card.dart';

typedef RestaurantMenuLoader =
    Future<RestaurantMenu> Function(String restaurantId);

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

  late Future<RestaurantMenu> _menuFuture;
  late Future<List<RestaurantLocation>> _locationsFuture;
  String? _selectedCategoryId;

  RestaurantMenuLoader get _menuLoader =>
      widget.menuLoader ?? RestaurantMenuRepository().fetchMenu;

  @override
  void initState() {
    super.initState();
    _menuFuture = _menuLoader(widget.restaurantId);
    _locationsFuture = _loadLocations();
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

  Future<void> _addToCart(RestaurantMenu menu, MenuItem menuItem) async {
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
      var result = await controller.addItem(cartItem);
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
        );
      }

      if (!mounted) {
        return;
      }
      final message = switch (result) {
        CartAddResult.quantityIncreased =>
          '${menuItem.name} quantity increased',
        CartAddResult.replacedRestaurant =>
          'New cart started with ${menuItem.name}',
        CartAddResult.maximumReached =>
          '${menuItem.name} is already at the maximum quantity',
        _ => '${menuItem.name} added to cart',
      };
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
    } on Object {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The item was added, but the cart could not be saved.'),
        ),
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
            sectionKeyFor: (categoryId) =>
                _sectionKeys.putIfAbsent(categoryId, GlobalKey.new),
            onCategorySelected: _selectCategory,
            onAddToCart: (item) => _addToCart(snapshot.requireData, item),
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
    required this.sectionKeyFor,
    required this.onCategorySelected,
    required this.onAddToCart,
  });

  final RestaurantMenu menu;
  final Future<List<RestaurantLocation>> locationsFuture;
  final String? selectedCategoryId;
  final GlobalKey Function(String categoryId) sectionKeyFor;
  final ValueChanged<MenuCategory> onCategorySelected;
  final ValueChanged<MenuItem> onAddToCart;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _RestaurantAppBar(menu: menu),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  TwSpacing.x5,
                  TwSpacing.x6,
                  TwSpacing.x5,
                  TwSpacing.x5,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(menu.restaurant.name, style: TwText.text2xl()),
                    if (menu.restaurant.description.trim().isNotEmpty) ...[
                      const SizedBox(height: TwSpacing.x2),
                      Text(menu.restaurant.description, style: TwText.textSm()),
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
                          style: TwText.fontBoldSm(),
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
                          style: TwText.textSm(),
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
                                  style: TwText.textSm(),
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
          for (final category in menu.categories)
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TwSpacing.x5,
                      TwSpacing.x6,
                      TwSpacing.x5,
                      0,
                    ),
                    child: Column(
                      key: sectionKeyFor(category.id),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                category.name,
                                style: TwText.textXl(),
                              ),
                            ),
                            Text(
                              '${category.items.length} '
                              '${category.items.length == 1 ? 'item' : 'items'}',
                              style: TwText.textXs().copyWith(
                                color: TwColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: TwSpacing.x4),
                        for (
                          var index = 0;
                          index < category.items.length;
                          index++
                        ) ...[
                          MenuItemCard(
                            item: category.items[index],
                            onAddToCart: () =>
                                onAddToCart(category.items[index]),
                          ),
                          if (index != category.items.length - 1)
                            const SizedBox(height: TwSpacing.x3),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        const SliverToBoxAdapter(child: SizedBox(height: TwSpacing.x10)),
      ],
    );
  }
}

class _RestaurantAppBar extends StatelessWidget {
  const _RestaurantAppBar({required this.menu});

  final RestaurantMenu menu;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return SliverAppBar(
      pinned: true,
      expandedHeight: 230,
      backgroundColor: palette.accent,
      foregroundColor: palette.onAccent,
      title: Text(
        menu.restaurant.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TwText.fontBoldBase().copyWith(color: palette.onAccent),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: _RestaurantHero(imageUrl: menu.restaurant.logoUrl),
      ),
    );
  }
}

class _RestaurantHero extends StatelessWidget {
  const _RestaurantHero({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl.trim();
    final image = trimmedUrl.isEmpty
        ? const _RestaurantHeroFallback()
        : CachedNetworkImage(
            imageUrl: trimmedUrl,
            fit: BoxFit.cover,
            placeholder: (_, _) =>
                const _RestaurantHeroFallback(showLoader: true),
            errorWidget: (_, _, _) => const _RestaurantHeroFallback(),
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                TwColors.slate900.withOpacityValue(85 / 255),
                TwColors.slate900.withOpacityValue(34 / 255),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RestaurantHeroFallback extends StatelessWidget {
  const _RestaurantHeroFallback({this.showLoader = false});

  final bool showLoader;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return ColoredBox(
      color: palette.accent,
      child: Center(
        child: showLoader
            ? CircularProgressIndicator(color: palette.onAccent)
            : Icon(Icons.restaurant_rounded, color: palette.onAccent, size: 72),
      ),
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
  double get minExtent => 66;

  @override
  double get maxExtent => 66;

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
            padding: const EdgeInsets.symmetric(
              horizontal: TwSpacing.x5,
              vertical: TwSpacing.x3,
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
                labelStyle: TwText.textXs().copyWith(
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
                Text('Loading menu…', style: TwText.textSm()),
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
                  backgroundColor: palette.card,
                  borderColor: palette.border,
                  borderRadius: 18,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        color: palette.accent,
                        size: 42,
                      ),
                      const SizedBox(height: TwSpacing.x3),
                      Text(
                        'We could not load this menu',
                        style: TwText.textXl(),
                      ),
                      const SizedBox(height: TwSpacing.x2),
                      Text(
                        'Check your connection and try again.',
                        textAlign: TextAlign.center,
                        style: TwText.textSm(),
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
            Text('No menu items yet', style: TwText.textXl()),
            const SizedBox(height: TwSpacing.x2),
            Text(
              'This restaurant has not added any items.',
              textAlign: TextAlign.center,
              style: TwText.textSm(),
            ),
          ],
        ),
      ),
    );
  }
}
