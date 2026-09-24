import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../platform/localization/app_money.dart';
import '../../shared/merchant_media_store.dart';
import '../../shared/merchant_photo_field.dart';
import '../../store/models/merchant_vertical.dart';
import '../models/merchant_catalog_item.dart';
import 'catalog_item_form.dart';
import 'merchant_catalog_controller.dart';

/// "Catalog" screen (ported from `merchant_app`, originally issue #133,
/// unified into the main app by issue #232): list, add, edit, delete, and
/// toggle availability for the merchant's own items in [storeId] --
/// `menu_items` / `grocery_products` / `pharmacy_products` depending on
/// [vertical].
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    required this.vertical,
    required this.storeId,
    required this.storeName,
    this.controller,
    this.media,
    this.photoPicker,
  });

  final MerchantVertical vertical;
  final String storeId;
  final String storeName;

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
  late final MerchantCatalogController _controller =
      widget.controller ??
      MerchantCatalogController.supabase(
        Supabase.instance.client,
        vertical: widget.vertical,
        storeId: widget.storeId,
      );
  late final bool _ownsController = widget.controller == null;
  late final MerchantMediaStore _media =
      widget.media ?? SupabaseMerchantMediaStore();

  @override
  void initState() {
    super.initState();
    // Start the load before attaching the listener -- see
    // `MyStoreScreen.initState`'s comment for why the order matters.
    if (!_controller.hasLoaded && !_controller.isLoading) {
      unawaited(_controller.load());
    }
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  Future<void> _openForm({MerchantCatalogItem? initial}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CatalogItemForm(
        controller: _controller,
        vertical: widget.vertical,
        storeId: widget.storeId,
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
    final deleted = await _controller.deleteItem(item);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.storeName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Catalog',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_controller.isLoading && !_controller.hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final loadError = _controller.loadError;
    if (loadError != null && _controller.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(loadError, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => unawaited(_controller.load()),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_controller.hasLoaded && _controller.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: Theme.of(context).disabledColor,
              ),
              const SizedBox(height: 16),
              const Text(
                'No items yet',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Add your first item to start selling.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
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
      onRefresh: () => _controller.load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: _controller.items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = _controller.items[index];
          return _CatalogItemTile(
            item: item,
            onEdit: () => _openForm(initial: item),
            onDelete: () => unawaited(_confirmDelete(item)),
            onToggleAvailability: () =>
                unawaited(_controller.toggleAvailability(item)),
          );
        },
      ),
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
        padding: const EdgeInsets.all(12),
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
                    const SizedBox(height: 2),
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
