import 'package:flutter/material.dart';

import '../../../../platform/localization/app_money.dart';
import '../../shared/merchant_media_store.dart';
import '../../shared/merchant_photo_field.dart';
import '../../store/models/merchant_vertical.dart';
import '../models/merchant_catalog_item.dart';
import 'merchant_catalog_controller.dart';

/// Add/edit form for one catalog item (ported from `merchant_app`,
/// originally issue #133, unified into the main app by issue #232), shown
/// in a modal bottom sheet from [CatalogScreen]. Fields shown depend on
/// [vertical] -- see `merchant_vertical.dart` / `merchant_catalog_item.dart`
/// for which columns each vertical's item table actually has.
class CatalogItemForm extends StatefulWidget {
  const CatalogItemForm({
    super.key,
    required this.controller,
    required this.vertical,
    required this.storeId,
    required this.media,
    this.initial,
    this.photoPicker,
  });

  final MerchantCatalogController controller;
  final MerchantVertical vertical;
  final String storeId;
  final MerchantMediaStore media;

  /// Overridable for tests; defaults to [pickAndCropMerchantPhoto].
  final MerchantPhotoPicker? photoPicker;

  /// `null` when adding a new item; the existing item when editing.
  final MerchantCatalogItem? initial;

  @override
  State<CatalogItemForm> createState() => _CatalogItemFormState();
}

class _CatalogItemFormState extends State<CatalogItemForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final MerchantPhotoSession _photos;
  String? _imageUrl;
  bool _isUploading = false;
  late final TextEditingController _availableQuantityController;
  late final TextEditingController _stockQuantityController;
  late bool _isAvailable;
  late GroceryPricingUnit _pricingUnit;
  String? _categoryId;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _priceController = TextEditingController(
      text: initial == null
          ? ''
          : (initial.priceCents / 100).toStringAsFixed(2),
    );
    _imageUrl = initial?.imageUrl;
    _photos = MerchantPhotoSession(media: widget.media, savedUrl: _imageUrl);
    _availableQuantityController = TextEditingController(
      text: initial?.availableQuantity?.toString() ?? '0',
    );
    _stockQuantityController = TextEditingController(
      text: initial?.stockQuantity?.toString() ?? '0',
    );
    _isAvailable = initial?.isAvailable ?? true;
    _pricingUnit = initial?.pricingUnit ?? GroceryPricingUnit.each;
    _categoryId = initial?.categoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _photos.discard();
    _availableQuantityController.dispose();
    _stockQuantityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final priceCents = AppMoney.parseToCents(_priceController.text);
    if (priceCents == null) {
      setState(() {});
      return;
    }

    final draft = MerchantCatalogItem(
      id: widget.initial?.id ?? '',
      storeId: widget.storeId,
      vertical: widget.vertical,
      name: _nameController.text,
      description: _descriptionController.text,
      priceCents: priceCents,
      isAvailable: _isAvailable,
      imageUrl: _imageUrl,
      pricingUnit: widget.vertical == MerchantVertical.grocery
          ? _pricingUnit
          : null,
      availableQuantity: widget.vertical == MerchantVertical.grocery
          ? double.tryParse(_availableQuantityController.text) ?? 0
          : null,
      categoryId: widget.vertical == MerchantVertical.pharmacy
          ? _categoryId
          : null,
      stockQuantity: widget.vertical == MerchantVertical.pharmacy
          ? int.tryParse(_stockQuantityController.text) ?? 0
          : null,
    );

    final succeeded = _isEditing
        ? await widget.controller.updateItem(draft)
        : await widget.controller.createItem(draft);
    if (succeeded) _photos.commit(_imageUrl);
    if (succeeded && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vertical = widget.vertical;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Edit item' : 'Add item',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter a name.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: vertical == MerchantVertical.grocery
                      ? 'Price (per unit, USD)'
                      : 'Price (USD)',
                  prefixText: r'$',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => AppMoney.parseToCents(value ?? '') == null
                    ? 'Enter a valid, non-negative price.'
                    : null,
              ),
              const SizedBox(height: 16),
              MerchantPhotoField(
                label: 'Item photo',
                imageUrl: _imageUrl,
                folder: MerchantMediaFolder.items,
                session: _photos,
                picker: widget.photoPicker,
                onChanged: (url) => setState(() => _imageUrl = url),
                onUploadingChanged: (value) =>
                    setState(() => _isUploading = value),
              ),
              if (vertical == MerchantVertical.grocery) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<GroceryPricingUnit>(
                  initialValue: _pricingUnit,
                  decoration: const InputDecoration(
                    labelText: 'Sold',
                    border: OutlineInputBorder(),
                  ),
                  items: GroceryPricingUnit.values
                      .map(
                        (unit) => DropdownMenuItem(
                          value: unit,
                          child: Text(unit.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setState(() => _pricingUnit = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _availableQuantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Available quantity',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    return (parsed == null || parsed < 0)
                        ? 'Enter a valid quantity.'
                        : null;
                  },
                ),
              ],
              if (vertical == MerchantVertical.pharmacy) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.controller.pharmacyCategories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => setState(() => _categoryId = value),
                  validator: (value) =>
                      value == null ? 'Choose a category.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _stockQuantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Stock quantity',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    return (parsed == null || parsed < 0)
                        ? 'Enter a valid quantity.'
                        : null;
                  },
                ),
              ],
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Available'),
                subtitle: const Text(
                  'Turn off to hide this item from customers without '
                  'deleting it.',
                ),
                value: _isAvailable,
                onChanged: (value) => setState(() => _isAvailable = value),
              ),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) {
                  final controller = widget.controller;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (controller.saveError != null) ...[
                        Text(
                          controller.saveError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      FilledButton(
                        onPressed: controller.isSaving || _isUploading
                            ? null
                            : _submit,
                        child: controller.isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_isEditing ? 'Save item' : 'Add item'),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
