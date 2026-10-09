import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/app_scope.dart';
import '../../../../config/tailwind.dart';
import '../../../../platform/localization/app_money.dart';
import '../../shared/merchant_media_store.dart';
import '../../shared/merchant_photo_field.dart';
import '../../store/presentation/merchant_store_controller.dart';
import '../../store/models/merchant_vertical.dart';
import '../models/merchant_catalog_item.dart';
import 'catalog_item_form.dart';
import 'merchant_catalog_controller.dart';

/// "Catalog" screen: list, add, edit, delete, and toggle availability for
/// the merchant's own items -- `menu_items` / `grocery_products` /
/// `pharmacy_products` depending on the vertical.
///
/// Reached either from `MyStoreScreen`'s "Manage catalog" button (which
/// already has the loaded [vertical]/[storeId]/[storeName] to hand), or
/// directly via `AppRoutes.merchantCatalog` (deep link / browser URL) -- a
/// go_router destination, like `RestaurantScreen`. [vertical]
/// and [storeId] are `null` in that second case, and this screen resolves
/// the signed-in merchant's own store itself, the same way
/// `OrdersScreen`/`MyStoreScreen` do (a merchant is modeled as owning at
/// most one store).
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    this.vertical,
    this.storeId,
    this.storeName,
    this.ownerId,
    this.storeController,
    this.controller,
    this.media,
    this.photoPicker,
  });

  /// Supplied together by `MyStoreScreen`; `null` on a cold open/deep link,
  /// in which case this screen resolves them itself (see [storeController]).
  final MerchantVertical? vertical;
  final String? storeId;
  final String? storeName;

  /// The signed-in merchant's `profiles.id` (== `auth.uid()`). Only used
  /// when [vertical]/[storeId] are not supplied -- defaults to the current
  /// Supabase session's user id (via `AppScope`).
  final String? ownerId;

  /// Overridable for tests; only used when [vertical]/[storeId] are not
  /// supplied. Defaults to a real Supabase-backed controller.
  final MerchantStoreController? storeController;

  /// Overridable for tests; defaults to a real Supabase-backed controller.
  final MerchantCatalogController? controller;

  /// Overridable for tests; defaults to the Supabase `merchant_media` bucket.
  final MerchantMediaStore? media;

  /// Overridable for tests; defaults to [pickAndCropMerchantPhoto].
  final MerchantPhotoPicker? photoPicker;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  MerchantStoreController? _ownStoreController;
  bool _ownsStoreController = false;
  MerchantCatalogController? _controller;
  bool _ownsController = false;
  late final MerchantMediaStore _media;
  String? _resolvedOwnerId;
  late SupabaseClient _supabaseClient;
  bool _dependenciesResolved = false;

  MerchantVertical? get _vertical =>
      widget.vertical ?? _ownStoreController?.store?.vertical;
  String? get _storeId => widget.storeId ?? _ownStoreController?.store?.id;
  String get _storeName =>
      widget.storeName ?? _ownStoreController?.store?.name ?? 'My store';

  // Resolved here rather than in field initializers / initState: reading
  // the Supabase client off `AppScope.of(context)` needs a
  // `BuildContext` that is allowed to look up an `InheritedWidget`, which
  // `didChangeDependencies` is and `initState` is not.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesResolved) return;
    _dependenciesResolved = true;

    _supabaseClient = AppScope.of(context).supabaseClient;
    _media = widget.media ?? SupabaseMerchantMediaStore();

    final injectedController = widget.controller;
    if (injectedController != null) {
      _controller = injectedController;
      _ownsController = false;
      // Start the load before attaching the listener -- see
      // `MyStoreScreen.initState`'s comment for why the order matters.
      if (!injectedController.hasLoaded && !injectedController.isLoading) {
        unawaited(injectedController.load());
      }
      injectedController.addListener(_onControllerChanged);
      return;
    }

    final vertical = widget.vertical;
    final storeId = widget.storeId;
    if (vertical != null && storeId != null) {
      _initController(vertical, storeId);
      return;
    }

    // Cold open/deep link: resolve the merchant's own store first.
    _resolvedOwnerId = widget.ownerId ?? _supabaseClient.auth.currentUser?.id;
    final ownerId = _resolvedOwnerId;
    if (ownerId == null) {
      return;
    }
    final storeController =
        widget.storeController ??
        MerchantStoreController.supabase(_supabaseClient);
    _ownStoreController = storeController;
    _ownsStoreController = widget.storeController == null;
    if (!storeController.hasLoaded && !storeController.isLoading) {
      unawaited(storeController.load(ownerId));
    }
    storeController.addListener(_onStoreChanged);
    _maybeInitControllerFromOwnStore();
  }

  @override
  void dispose() {
    _ownStoreController?.removeListener(_onStoreChanged);
    if (_ownsStoreController) {
      _ownStoreController?.dispose();
    }
    _controller?.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller?.dispose();
    }
    super.dispose();
  }

  void _onStoreChanged() {
    _maybeInitControllerFromOwnStore();
    setState(() {});
  }

  void _maybeInitControllerFromOwnStore() {
    if (_controller != null) return;
    final store = _ownStoreController?.store;
    if (store == null) return;
    _initController(store.vertical, store.id);
  }

  void _initController(MerchantVertical vertical, String storeId) {
    final controller = MerchantCatalogController.supabase(
      _supabaseClient,
      vertical: vertical,
      storeId: storeId,
    );
    _controller = controller;
    _ownsController = true;
    controller.addListener(_onControllerChanged);
    unawaited(controller.load());
  }

  void _onControllerChanged() => setState(() {});

  Future<void> _openForm({MerchantCatalogItem? initial}) {
    final vertical = _vertical!;
    final storeId = _storeId!;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TwRadius.hero),
        ),
      ),
      builder: (_) => CatalogItemForm(
        controller: _controller!,
        vertical: vertical,
        storeId: storeId,
        media: _media,
        photoPicker: widget.photoPicker,
        initial: initial,
      ),
    );
  }

  Future<void> _confirmDelete(MerchantCatalogItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('"${item.name}" will be removed from your catalog.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deleted = await _controller!.deleteItem(item);
    final imageUrl = item.imageUrl;
    if (deleted && imageUrl != null) {
      // Best-effort: a leftover file never blocks the merchant.
      unawaited(
        _media.deleteIfOwned(imageUrl).catchError((Object error) {
          debugPrint('Could not delete photo for "${item.name}": $error');
        }),
      );
    }
  }

  /// Once a self-resolved [_ownStoreController] has finished loading (found
  /// a store or not), there is no further self-resolution step left to wait
  /// on -- so [_body] should show the "no store" state rather than spin
  /// forever.
  bool get _selfResolutionFinished {
    if (_resolvedOwnerId == null) return true;
    return _ownStoreController?.hasLoaded ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_storeName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(TwSpacing.x5),
          child: Padding(
            padding: const EdgeInsets.only(bottom: TwSpacing.x2),
            child: Text(
              'Catalog',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ),
        ),
      ),
      floatingActionButton: _controller == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            ),
      body: _body(),
    );
  }

  Widget _body() {
    final controller = _controller;
    if (controller == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(TwSpacing.x6),
          child: _selfResolutionFinished
              ? const _NoStoreView()
              : const CircularProgressIndicator(),
        ),
      );
    }

    if (controller.isLoading && !controller.hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final loadError = controller.loadError;
    if (loadError != null && controller.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(TwSpacing.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: TwSpacing.x4),
              Text(loadError, textAlign: TextAlign.center),
              const SizedBox(height: TwSpacing.x4),
              FilledButton(
                onPressed: () => unawaited(controller.load()),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (controller.hasLoaded && controller.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(TwSpacing.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: Theme.of(context).disabledColor,
              ),
              const SizedBox(height: TwSpacing.x4),
              const Text(
                'No items yet',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: TwSpacing.x1),
              const Text(
                'Add your first item to start selling.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: TwSpacing.x4),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => controller.load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          TwSpacing.screenX,
          TwSpacing.x4,
          TwSpacing.screenX,
          TwSpacing.x12 * 2,
        ),
        itemCount: controller.items.length,
        separatorBuilder: (_, _) => const SizedBox(height: TwSpacing.x2),
        itemBuilder: (context, index) {
          final item = controller.items[index];
          return _CatalogItemTile(
            item: item,
            onEdit: () => _openForm(initial: item),
            onDelete: () => unawaited(_confirmDelete(item)),
            onToggleAvailability: () =>
                unawaited(controller.toggleAvailability(item)),
          );
        },
      ),
    );
  }
}

/// Shown when a cold open/deep link to `AppRoutes.merchantCatalog` resolves
/// a signed-in merchant with no store yet (or no session at all) -- mirrors
/// `OrdersScreen._NoStoreView`.
class _NoStoreView extends StatelessWidget {
  const _NoStoreView();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.storefront_outlined,
          size: 48,
          color: Theme.of(context).disabledColor,
        ),
        const SizedBox(height: TwSpacing.x4),
        const Text(
          'Set up your store first',
          style: TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: TwSpacing.x1),
        const Text(
          'Set up your store from the "My Store" tab to manage its catalog.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _CatalogItemTile extends StatelessWidget {
  const _CatalogItemTile({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleAvailability,
  });

  final MerchantCatalogItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleAvailability;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TwSpacing.x3_5,
          vertical: TwSpacing.listRowY,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if ((item.description ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    AppMoney.formatCents(item.priceCents),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Switch(
                  value: item.isAvailable,
                  onChanged: (_) => onToggleAvailability(),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
