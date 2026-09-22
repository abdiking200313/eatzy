import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/service_module.dart';
import '../config/theme.dart';
import '../platform/discovery/store_listing.dart';
import '../platform/discovery/store_listing_repository.dart';
import '../services/food/data/category_repository.dart';
import '../services/food/models/category.dart';
import '../widgets/app_cards.dart';
import '../widgets/app_scaffold.dart';

/// The bottom-nav "Explore" tab: a search + discovery feed across all three
/// verticals, distinct from `screens/categories.dart` (the "Services" page,
/// a simple vertical picker reached from the home grid's "More" tile).
///
/// There is deliberately no location/distance data anywhere in this app, so
/// this stays a browse/search feed rather than a proximity feed (no map, no
/// "X km away").
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    this.storeListingLoader,
    this.categoryRepository,
  });

  /// Test seam mirroring `SuperAppHomeScreen.storeListingLoader` — takes the
  /// active vertical filter (null = All) and returns matching stores.
  final Future<List<StoreListing>> Function(ServiceId? filter)?
  storeListingLoader;

  /// Test seam mirroring `FoodCategoriesScreen.repository`.
  final CategoryRepository? categoryRepository;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchController = TextEditingController();
  ServiceId? _filter;
  String _query = '';
  late Future<List<StoreListing>> _storesFuture = _loadStores();
  late final Future<List<Category>> _categoriesFuture =
      (widget.categoryRepository ?? CategoryRepository()).fetchCategories();

  // `async`, not a bare passthrough: this keeps a synchronous throw from
  // constructing the default `StoreListingRepository()` (e.g. Supabase not
  // yet initialized) inside the async/Future machinery, so it surfaces as a
  // rejected Future the FutureBuilder below can render an error state for,
  // instead of crashing this screen's `State` construction outright.
  Future<List<StoreListing>> _loadStores() async {
    final loader =
        widget.storeListingLoader ??
        (ServiceId? filter) =>
            StoreListingRepository().fetchStores(filter: filter);
    return loader(_filter);
  }

  void _setFilter(ServiceId? filter) {
    if (filter == _filter) {
      return;
    }
    setState(() {
      _filter = filter;
      _storesFuture = _loadStores();
    });
  }

  void _setQuery(String value) {
    setState(() => _query = value);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Explore',
      showBackButton: false,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TwSpacing.x5,
              TwSpacing.x4,
              TwSpacing.x5,
              0,
            ),
            child: _SearchField(
              controller: _searchController,
              onChanged: _setQuery,
            ),
          ),
          const SizedBox(height: TwSpacing.x4),
          _FilterChipsRow(selected: _filter, onSelected: _setFilter),
          const SizedBox(height: TwSpacing.x3),
          _CategoryChipsRow(
            future: _categoriesFuture,
            onSelected: (name) {
              _searchController.text = name;
              _setQuery(name);
            },
          ),
          const SizedBox(height: TwSpacing.x3),
          Expanded(
            child: FutureBuilder<List<StoreListing>>(
              future: _storesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const _Message(
                    icon: Icons.cloud_off_outlined,
                    text: 'Stores could not be loaded.',
                  );
                }

                final query = _query.trim().toLowerCase();
                final stores = (snapshot.data ?? const <StoreListing>[])
                    .where(
                      (store) =>
                          query.isEmpty ||
                          store.name.toLowerCase().contains(query),
                    )
                    .toList(growable: false);

                if (stores.isEmpty) {
                  return const _Message(
                    icon: Icons.storefront_outlined,
                    text: 'No stores match your search.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    TwSpacing.x5,
                    0,
                    TwSpacing.x5,
                    TwSpacing.x5,
                  ),
                  itemCount: stores.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: TwSpacing.x3),
                  itemBuilder: (context, index) {
                    final store = stores[index];
                    return StoreListCard(
                      name: store.name,
                      subtitle: store.subtitle,
                      imageUrl: store.imageUrl,
                      accentColor: ServiceThemes.forId(store.serviceId).accent,
                      onTap: () => context.push(store.route),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A white pill search bar matching the home header's search bar look
/// (`_HomeHeader` in `super_app_home_screen.dart`), but with a real,
/// screen-owned `TextField` instead of a tap-to-navigate stand-in.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TwColors.white,
      elevation: 0.6,
      shadowColor: TwColors.slate900.withOpacityValue(0.1),
      borderRadius: BorderRadius.circular(TwRadius.full),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: TwSpacing.x4),
        child: Row(
          children: [
            const Icon(Icons.search, color: TwColors.textMuted),
            const SizedBox(width: TwSpacing.x3),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: TwText.textBase,
                decoration: const InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  hintText: 'Search restaurants, stores...',
                  hintStyle: TextStyle(color: TwColors.textMuted),
                  contentPadding: EdgeInsets.symmetric(vertical: TwSpacing.x3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal `All / Food / Grocery / Pharmacy` filter chips controlling the
/// `ServiceId? filter` passed to `StoreListingRepository.fetchStores`.
class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow({required this.selected, required this.onSelected});

  final ServiceId? selected;
  final ValueChanged<ServiceId?> onSelected;

  static const _options = <(String, ServiceId?)>[
    ('All', null),
    ('Food', ServiceId.food),
    ('Grocery', ServiceId.grocery),
    ('Pharmacy', ServiceId.pharmacy),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: TwSpacing.x5),
        itemCount: _options.length,
        separatorBuilder: (_, _) => const SizedBox(width: TwSpacing.x2),
        itemBuilder: (context, index) {
          final (label, id) = _options[index];
          final isSelected = id == selected;
          final accent = id == null
              ? TwColors.primary
              : ServiceThemes.forId(id).accent;
          return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (_) => onSelected(id),
            backgroundColor: TwColors.card,
            selectedColor: accent.withOpacityValue(0.14),
            side: BorderSide(color: isSelected ? accent : TwColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(TwRadius.full),
            ),
            labelStyle: TwText.textXs.copyWith(
              color: isSelected ? accent : TwColors.textMuted,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          );
        },
      ),
    );
  }
}

/// Horizontal food-category chips (same `CategoryRepository`/`Category`
/// `FoodCategoriesScreen` uses). Tapping one filters the store feed
/// client-side by name, matching the search box — a secondary/best-effort
/// element rather than a true category-to-store filter, since no such
/// server-side link exists yet.
class _CategoryChipsRow extends StatelessWidget {
  const _CategoryChipsRow({required this.future, required this.onSelected});

  final Future<List<Category>> future;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: FutureBuilder<List<Category>>(
        future: future,
        builder: (context, snapshot) {
          final categories = snapshot.data ?? const <Category>[];
          if (categories.isEmpty) {
            return const SizedBox.shrink();
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: TwSpacing.x5),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: TwSpacing.x2),
            itemBuilder: (context, index) {
              final category = categories[index];
              return ActionChip(
                label: Text(category.name),
                onPressed: () => onSelected(category.name),
                backgroundColor: TwColors.card,
                side: const BorderSide(color: TwColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(TwRadius.full),
                ),
                labelStyle: TwText.textXs.copyWith(color: TwColors.textMuted),
              );
            },
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TwSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: TwColors.textMuted, size: 48),
            const SizedBox(height: TwSpacing.x3),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
