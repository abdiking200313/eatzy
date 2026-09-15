import 'package:merchant_app/features/catalog/data/merchant_catalog_repository.dart';
import 'package:merchant_app/features/catalog/models/merchant_catalog_item.dart';
import 'package:merchant_app/features/store/data/merchant_store_repository.dart';
import 'package:merchant_app/features/store/models/merchant_store.dart';
import 'package:merchant_app/features/store/models/merchant_vertical.dart';

/// In-memory fakes for issue #133's repository interfaces, so widget/unit
/// tests can exercise the controllers/screens without a live Supabase
/// project or network access (this sandbox has neither -- see the issue's
/// own verification notes).

class FakeMerchantStoreRepository implements MerchantStoreRepository {
  FakeMerchantStoreRepository({MerchantStore? initialStore})
    : _store = initialStore;

  MerchantStore? _store;

  /// When set, [fetchOwnStore] / [createStore] / [updateStore] throw this
  /// instead of succeeding, to exercise error states.
  Object? failureToThrow;

  @override
  Future<MerchantStore?> fetchOwnStore(String ownerId) async {
    if (failureToThrow != null) throw failureToThrow!;
    return _store;
  }

  @override
  Future<MerchantStore> createStore({
    required MerchantVertical vertical,
    required String ownerId,
    required String name,
    required String location,
    String? description,
  }) async {
    if (failureToThrow != null) throw failureToThrow!;
    final created = MerchantStore(
      id: 'new-store-1',
      vertical: vertical,
      name: name.trim(),
      location: location.trim(),
      isOpen: true,
      description: vertical.storeSupportsDescription
          ? description?.trim()
          : null,
    );
    _store = created;
    return created;
  }

  @override
  Future<MerchantStore> updateStore(
    MerchantStore store, {
    required String ownerId,
    required String name,
    required String location,
    required bool isOpen,
    String? description,
    String? imageUrl,
  }) async {
    if (failureToThrow != null) throw failureToThrow!;
    final updated = store.copyWith(
      name: name.trim(),
      location: location.trim(),
      isOpen: isOpen,
      description: description?.trim(),
      imageUrl: imageUrl?.trim(),
    );
    _store = updated;
    return updated;
  }
}

class FakeMerchantCatalogRepository implements MerchantCatalogRepository {
  FakeMerchantCatalogRepository({
    List<MerchantCatalogItem>? initialItems,
    List<PharmacyCategory>? categories,
  }) : _items = List.of(initialItems ?? const []),
       _categories = categories ?? const [];

  final List<MerchantCatalogItem> _items;
  final List<PharmacyCategory> _categories;

  /// When set, every method throws this instead of succeeding.
  Object? failureToThrow;

  int _nextId = 1;

  @override
  Future<List<MerchantCatalogItem>> fetchItems({
    required MerchantVertical vertical,
    required String storeId,
  }) async {
    if (failureToThrow != null) throw failureToThrow!;
    return List.of(_items);
  }

  @override
  Future<MerchantCatalogItem> createItem(MerchantCatalogItem draft) async {
    if (failureToThrow != null) throw failureToThrow!;
    final created = MerchantCatalogItem(
      id: 'fake-item-${_nextId++}',
      storeId: draft.storeId,
      vertical: draft.vertical,
      name: draft.name.trim(),
      description: draft.description,
      priceCents: draft.priceCents,
      isAvailable: draft.isAvailable,
      imageUrl: draft.imageUrl,
      pricingUnit: draft.pricingUnit,
      availableQuantity: draft.availableQuantity,
      categoryId: draft.categoryId,
      stockQuantity: draft.stockQuantity,
    );
    _items.add(created);
    return created;
  }

  @override
  Future<MerchantCatalogItem> updateItem(MerchantCatalogItem item) async {
    if (failureToThrow != null) throw failureToThrow!;
    final index = _items.indexWhere((existing) => existing.id == item.id);
    if (index == -1) throw StateError('Item not found: ${item.id}');
    _items[index] = item;
    return item;
  }

  @override
  Future<void> deleteItem({
    required MerchantVertical vertical,
    required String itemId,
  }) async {
    if (failureToThrow != null) throw failureToThrow!;
    _items.removeWhere((existing) => existing.id == itemId);
  }

  @override
  Future<MerchantCatalogItem> setAvailability({
    required MerchantCatalogItem item,
    required bool isAvailable,
  }) async {
    if (failureToThrow != null) throw failureToThrow!;
    final index = _items.indexWhere((existing) => existing.id == item.id);
    if (index == -1) throw StateError('Item not found: ${item.id}');
    final updated = MerchantCatalogItem(
      id: item.id,
      storeId: item.storeId,
      vertical: item.vertical,
      name: item.name,
      description: item.description,
      priceCents: item.priceCents,
      isAvailable: isAvailable,
      imageUrl: item.imageUrl,
      pricingUnit: item.pricingUnit,
      availableQuantity: item.availableQuantity,
      categoryId: item.categoryId,
      stockQuantity: item.stockQuantity,
    );
    _items[index] = updated;
    return updated;
  }

  @override
  Future<List<PharmacyCategory>> fetchPharmacyCategories() async {
    if (failureToThrow != null) throw failureToThrow!;
    return List.of(_categories);
  }
}
