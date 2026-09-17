import 'package:merchant_app/features/catalog/data/merchant_catalog_repository.dart';
import 'package:merchant_app/features/catalog/models/merchant_catalog_item.dart';
import 'package:merchant_app/features/orders/data/merchant_orders_repository.dart';
import 'package:merchant_app/features/orders/models/merchant_order.dart';
import 'package:merchant_app/features/orders/models/merchant_order_vertical.dart';
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

/// In-memory fake for issue #134's `MerchantOrdersRepository`.
/// [advanceOrderStatus] re-implements the same legal-transition check as
/// `is_legal_order_status_transition` in
/// `supabase/migrations/20260830140000_add_order_status_transition_rpcs.sql`
/// (via `MerchantVertical.orderStatusFlow`, the same source of truth the
/// real app reads), so tests can exercise both a legal advance and a
/// rejected illegal one without a live Supabase project.
class FakeMerchantOrdersRepository implements MerchantOrdersRepository {
  FakeMerchantOrdersRepository({List<MerchantOrder>? initialOrders})
    : _orders = List.of(initialOrders ?? const []);

  final List<MerchantOrder> _orders;

  /// When set, every method throws this instead of succeeding.
  Object? failureToThrow;

  @override
  Future<List<MerchantOrder>> fetchOrders({
    required MerchantVertical vertical,
    required String storeId,
  }) async {
    if (failureToThrow != null) throw failureToThrow!;
    return List.of(_orders);
  }

  @override
  Future<String> advanceOrderStatus({
    required MerchantVertical vertical,
    required String orderId,
    required String newStatus,
  }) async {
    if (failureToThrow != null) throw failureToThrow!;
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index == -1) {
      throw const OrderStatusTransitionException('Order not found');
    }
    final current = _orders[index];
    if (!_isLegalTransition(vertical, current.status, newStatus)) {
      throw OrderStatusTransitionException(
        'Illegal ${vertical.name} order status transition: '
        '${current.status} -> $newStatus',
      );
    }
    _orders[index] = current.copyWith(status: newStatus);
    return newStatus;
  }

  static bool _isLegalTransition(
    MerchantVertical vertical,
    String from,
    String to,
  ) {
    final flow = vertical.orderStatusFlow;
    final fromIndex = flow.indexOf(from);
    if (to == 'cancelled') {
      return fromIndex == 0 || fromIndex == 1;
    }
    final toIndex = flow.indexOf(to);
    return fromIndex != -1 && toIndex == fromIndex + 1;
  }
}
