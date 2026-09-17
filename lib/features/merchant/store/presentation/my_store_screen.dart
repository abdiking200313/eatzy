import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../catalog/presentation/catalog_screen.dart';
import '../models/merchant_store.dart';
import '../models/merchant_vertical.dart';
import 'merchant_store_controller.dart';

/// "My Store" screen (ported from `merchant_app`, originally issue #133,
/// unified into the main app by issue #232): view and edit the signed-in
/// merchant's own store profile (name, description, address, open/closed,
/// image), or create one if they don't have one yet. Scoped entirely by
/// `owner_id` -- see `merchant_store_repository.dart`'s header for the RLS
/// this mirrors.
class MyStoreScreen extends StatefulWidget {
  const MyStoreScreen({super.key, required this.ownerId, this.controller});

  /// The signed-in merchant's `profiles.id` (== `auth.uid()`).
  final String ownerId;

  /// Overridable for tests; defaults to a real Supabase-backed controller.
  final MerchantStoreController? controller;

  @override
  State<MyStoreScreen> createState() => _MyStoreScreenState();
}

class _MyStoreScreenState extends State<MyStoreScreen> {
  late final MerchantStoreController _controller =
      widget.controller ??
      MerchantStoreController.supabase(Supabase.instance.client);
  late final bool _ownsController = widget.controller == null;

  @override
  void initState() {
    super.initState();
    // Start the load *before* attaching the listener: `load`'s synchronous
    // prefix (setting `isLoading` and calling `notifyListeners()`) runs
    // immediately, before its first `await`, and calling `setState` that
    // early -- still inside this `initState`/first-build pass -- would
    // throw. Mirrors the root app's `GroceryScreen.initState`.
    if (!_controller.hasLoaded && !_controller.isLoading) {
      unawaited(_controller.load(widget.ownerId));
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

  @override
  Widget build(BuildContext context) {
    if (_controller.isLoading && !_controller.hasLoaded) {
      return const _LoadingView();
    }

    final loadError = _controller.loadError;
    if (loadError != null && _controller.store == null) {
      return _ErrorView(
        message: loadError,
        onRetry: () => unawaited(_controller.load(widget.ownerId)),
      );
    }

    final store = _controller.store;
    if (store == null) {
      return _CreateStoreView(controller: _controller, ownerId: widget.ownerId);
    }

    return _StoreForm(
      key: ValueKey(store.id),
      controller: _controller,
      store: store,
      ownerId: widget.ownerId,
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
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
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

/// Empty state: the merchant has no store yet in any vertical. Lets them
/// pick a vertical and create one -- required so a brand-new merchant
/// account has any way to reach the catalog screen at all, per the trust
/// model in
/// `supabase/migrations/20260830130000_add_merchant_catalog_write_policies.sql`
/// ("a profile with role 'merchant' ... may create a store and its items").
class _CreateStoreView extends StatefulWidget {
  const _CreateStoreView({required this.controller, required this.ownerId});

  final MerchantStoreController controller;
  final String ownerId;

  @override
  State<_CreateStoreView> createState() => _CreateStoreViewState();
}

class _CreateStoreViewState extends State<_CreateStoreView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  MerchantVertical _vertical = MerchantVertical.food;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final succeeded = await widget.controller.createStore(
      vertical: _vertical,
      ownerId: widget.ownerId,
      name: _nameController.text,
      location: _locationController.text,
      description: _vertical.storeSupportsDescription
          ? _descriptionController.text
          : null,
    );
    if (succeeded && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Store created.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 48,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 12),
            Text(
              "You don't have a store yet",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Choose a service and set up your store profile to start '
              'selling.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            SegmentedButton<MerchantVertical>(
              segments: MerchantVertical.values
                  .map(
                    (vertical) => ButtonSegment(
                      value: vertical,
                      label: Text(vertical.displayName),
                    ),
                  )
                  .toList(growable: false),
              selected: {_vertical},
              onSelectionChanged: (selection) =>
                  setState(() => _vertical = selection.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Store name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter a store name.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: _vertical.storeLocationLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_vertical.storeSupportsDescription) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (controller.saveError != null) ...[
              const SizedBox(height: 12),
              Text(
                controller.saveError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: controller.isSaving ? null : _submit,
              child: controller.isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create store'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loaded state: edit the merchant's existing store.
class _StoreForm extends StatefulWidget {
  const _StoreForm({
    super.key,
    required this.controller,
    required this.store,
    required this.ownerId,
  });

  final MerchantStoreController controller;
  final MerchantStore store;
  final String ownerId;

  @override
  State<_StoreForm> createState() => _StoreFormState();
}

class _StoreFormState extends State<_StoreForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageUrlController;
  late bool _isOpen;

  @override
  void initState() {
    super.initState();
    final store = widget.store;
    _nameController = TextEditingController(text: store.name);
    _locationController = TextEditingController(text: store.location);
    _descriptionController = TextEditingController(
      text: store.description ?? '',
    );
    _imageUrlController = TextEditingController(text: store.imageUrl ?? '');
    _isOpen = store.isOpen;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final vertical = widget.store.vertical;
    final succeeded = await widget.controller.updateStore(
      ownerId: widget.ownerId,
      name: _nameController.text,
      location: _locationController.text,
      isOpen: _isOpen,
      description: vertical.storeSupportsDescription
          ? _descriptionController.text
          : null,
      imageUrl: vertical.storeSupportsImage ? _imageUrlController.text : null,
    );
    if (succeeded && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Store saved.')));
    }
  }

  void _openCatalog() {
    final store = widget.controller.store ?? widget.store;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CatalogScreen(
          vertical: store.vertical,
          storeId: store.id,
          storeName: store.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final vertical = widget.store.vertical;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.storefront_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${vertical.displayName} store',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Store name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter a store name.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: vertical.storeLocationLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            if (vertical.storeSupportsDescription) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (vertical.storeSupportsImage) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'Image URL',
                  helperText:
                      'A hosted image link (v1 simplification -- no in-app '
                      'image upload yet).',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Open for business'),
              subtitle: Text(
                _isOpen
                    ? 'Customers can see and order from this store.'
                    : 'This store is hidden from customers.',
              ),
              value: _isOpen,
              onChanged: (value) => setState(() => _isOpen = value),
            ),
            if (controller.saveError != null) ...[
              const SizedBox(height: 8),
              Text(
                controller.saveError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: controller.isSaving ? null : _submit,
              child: controller.isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save changes'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openCatalog,
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Manage catalog'),
            ),
          ],
        ),
      ),
    );
  }
}
