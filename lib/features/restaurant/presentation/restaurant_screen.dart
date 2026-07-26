import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../config/theme.dart';
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
  });

  final String restaurantId;
  final RestaurantMenuLoader? menuLoader;

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen> {
  final _sectionKeys = <String, GlobalKey>{};

  late Future<RestaurantMenu> _menuFuture;
  String? _selectedCategoryId;

  RestaurantMenuLoader get _menuLoader =>
      widget.menuLoader ?? RestaurantMenuRepository().fetchMenu;

  @override
  void initState() {
    super.initState();
    _menuFuture = _menuLoader(widget.restaurantId);
  }

  @override
  void didUpdateWidget(covariant RestaurantScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restaurantId != widget.restaurantId ||
        oldWidget.menuLoader != widget.menuLoader) {
      _sectionKeys.clear();
      _selectedCategoryId = null;
      _menuFuture = _menuLoader(widget.restaurantId);
    }
  }

  void _retry() {
    setState(() {
      _menuFuture = _menuLoader(widget.restaurantId);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwColors.bg,
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
            selectedCategoryId: _selectedCategoryId,
            sectionKeyFor: (categoryId) =>
                _sectionKeys.putIfAbsent(categoryId, GlobalKey.new),
            onCategorySelected: _selectCategory,
          );
        },
      ),
    );
  }
}

class _RestaurantMenuView extends StatelessWidget {
  const _RestaurantMenuView({
    required this.menu,
    required this.selectedCategoryId,
    required this.sectionKeyFor,
    required this.onCategorySelected,
  });

  final RestaurantMenu menu;
  final String? selectedCategoryId;
  final GlobalKey Function(String categoryId) sectionKeyFor;
  final ValueChanged<MenuCategory> onCategorySelected;

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
                        const Icon(
                          Icons.restaurant_menu_rounded,
                          size: 18,
                          color: TwColors.primary,
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
                          SizedBox(
                            height: 136,
                            child: MenuItemCard(item: category.items[index]),
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
    return SliverAppBar(
      pinned: true,
      expandedHeight: 230,
      backgroundColor: TwColors.primary,
      foregroundColor: Colors.white,
      title: Text(
        menu.restaurant.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TwText.fontBoldBase().copyWith(color: Colors.white),
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
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x55000000), Color(0x22000000)],
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
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: TwColors.primaryGradient),
      child: Center(
        child: showLoader
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(
                Icons.restaurant_rounded,
                color: Colors.white,
                size: 72,
              ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TwColors.bg,
        boxShadow: overlapsContent
            ? const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
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
                selectedColor: TwColors.primary,
                backgroundColor: TwColors.primarySoft,
                side: BorderSide(
                  color: isSelected ? TwColors.primary : TwColors.border,
                ),
                label: Text(category.name),
                labelStyle: TwText.textXs().copyWith(
                  color: isSelected ? Colors.white : TwColors.primary,
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
        const SliverAppBar(
          pinned: true,
          title: Text('Restaurant'),
          backgroundColor: TwColors.bg,
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
    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          pinned: true,
          title: Text('Restaurant'),
          backgroundColor: TwColors.bg,
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
                  backgroundColor: Colors.white,
                  borderColor: TwColors.border,
                  borderRadius: 18,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        color: TwColors.primary,
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
            const Icon(
              Icons.menu_book_rounded,
              size: 48,
              color: TwColors.primary,
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
