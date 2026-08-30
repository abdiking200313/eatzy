import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/data/rpc_helpers.dart';
import '../models/pharmacy_checkout.dart';
import '../models/pharmacy_product.dart';
import '../models/pharmacy_store.dart';

/// Default page size for [PharmacyRepository.fetchProducts] and
/// [PharmacyCatalogRepository.fetchProducts]. A result page shorter than
/// this signals the end of the catalog to callers doing infinite scroll
/// (see `PharmacyController.loadMore`).
const int pharmacyProductsPageSize = 30;

abstract interface class PharmacyRepository {
  /// Fetches OTC products stocked by [storeId] (`pharmacy_stores.id`),
  /// optionally narrowed by a case-insensitive [searchQuery] substring match
  /// on the product name, bounded to [limit] rows starting at [offset].
  /// Products are always scoped to one pharmacy at a time (issue #141) —
  /// there is no cross-pharmacy catalog query.
  Future<List<PharmacyProduct>> fetchProducts({
    required String storeId,
    String? searchQuery,
    int limit = pharmacyProductsPageSize,
    int offset = 0,
  });
}

abstract interface class PharmacyCatalogRepository {
  Future<List<PharmacyCategory>> fetchCategories();

  Future<List<PharmacyProduct>> fetchProducts({
    required String storeId,
    String? searchQuery,
    int limit = pharmacyProductsPageSize,
    int offset = 0,
  });
}

/// Fetches the list of pharmacies a customer can pick from
/// (`public.pharmacy_stores`), the pharmacy counterpart of
/// `RestaurantRepository`/`GroceryRepository.fetchStores`.
abstract interface class PharmacyStoreRepository {
  /// Fetches active pharmacies, optionally narrowed by a case-insensitive
  /// [searchQuery] substring match on the pharmacy name.
  Future<List<PharmacyStore>> fetchStores({String? searchQuery});
}

abstract interface class PharmacyOrderRepository {
  Future<String> placeOrder(PharmacyOrderRequest request);
}

class SeededPharmacyRepository implements PharmacyRepository {
  const SeededPharmacyRepository();

  /// The single pharmacy every seeded product belongs to — named after the
  /// same placeholder store id every pre-#129 `pharmacy_products` row was
  /// backfilled to server-side.
  static const defaultStoreId = 'legacy-pharmacy';

  static const products = <PharmacyProduct>[
    PharmacyProduct(
      id: 'pain-paracetamol',
      storeId: defaultStoreId,
      name: 'Paracetamol',
      description: 'Everyday relief for mild pain and fever.',
      category: 'Pain relief',
      unitPrice: 2.75,
      stockQuantity: 24,
      saleType: PharmacySaleType.overTheCounter,
    ),
    PharmacyProduct(
      id: 'cold-cough-syrup',
      storeId: defaultStoreId,
      name: 'Cough Syrup',
      description: 'Soothing syrup for common cough symptoms.',
      category: 'Cold & flu',
      unitPrice: 5.50,
      stockQuantity: 4,
      saleType: PharmacySaleType.overTheCounter,
    ),
    PharmacyProduct(
      id: 'first-aid-bandages',
      storeId: defaultStoreId,
      name: 'Adhesive Bandages',
      description: 'A pack of 30 sterile everyday bandages.',
      category: 'First aid',
      unitPrice: 3.25,
      stockQuantity: 18,
      saleType: PharmacySaleType.overTheCounter,
    ),
    PharmacyProduct(
      id: 'wellness-vitamin-c',
      storeId: defaultStoreId,
      name: 'Vitamin C',
      description: 'Thirty 500 mg vitamin C tablets.',
      category: 'Vitamins',
      unitPrice: 6.00,
      stockQuantity: 10,
      saleType: PharmacySaleType.overTheCounter,
    ),
    PharmacyProduct(
      id: 'allergy-antihistamine',
      storeId: defaultStoreId,
      name: 'Allergy Relief',
      description: 'Non-drowsy tablets for common allergy symptoms.',
      category: 'Allergy',
      unitPrice: 4.80,
      stockQuantity: 0,
      saleType: PharmacySaleType.overTheCounter,
    ),
  ];

  @override
  Future<List<PharmacyProduct>> fetchProducts({
    required String storeId,
    String? searchQuery,
    int limit = pharmacyProductsPageSize,
    int offset = 0,
  }) async {
    final query = searchQuery?.trim().toLowerCase();
    final hasSearch = query != null && query.isNotEmpty;
    final matches = products
        .where((product) => product.storeId == storeId)
        .where(
          (product) => !hasSearch || product.name.toLowerCase().contains(query),
        )
        .toList(growable: false);

    if (offset >= matches.length) {
      return const [];
    }
    final end = (offset + limit).clamp(0, matches.length);
    return List<PharmacyProduct>.unmodifiable(matches.sublist(offset, end));
  }
}

class SupabasePharmacyCatalogRepository
    implements PharmacyRepository, PharmacyCatalogRepository {
  const SupabasePharmacyCatalogRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<List<PharmacyCategory>> fetchCategories() async {
    final rows = await _client
        .from('pharmacy_categories')
        .select('id, name')
        .eq('is_active', true)
        .order('name');

    return List.unmodifiable(
      rows.map(
        (row) => PharmacyCategory.fromMap(Map<String, dynamic>.from(row)),
      ),
    );
  }

  @override
  Future<List<PharmacyProduct>> fetchProducts({
    required String storeId,
    String? searchQuery,
    int limit = pharmacyProductsPageSize,
    int offset = 0,
  }) async {
    final query = searchQuery?.trim();
    final hasSearch = query != null && query.isNotEmpty;

    var builder = _client
        .from('pharmacy_products')
        .select(
          'id, name, description, unit_price, stock_quantity, sale_type, '
          'store_id, pharmacy_categories!inner(id, name)',
        )
        .eq('is_active', true)
        .eq('sale_type', 'otc')
        .eq('store_id', storeId)
        .eq('pharmacy_categories.is_active', true);

    if (hasSearch) {
      builder = builder.ilike('name', '%$query%');
    }

    final rows = await builder.order('name').range(offset, offset + limit - 1);

    final products = rows
        .map((row) => PharmacyProduct.fromMap(Map<String, dynamic>.from(row)))
        .where((product) => product.isOverTheCounter)
        .toList(growable: false);
    return List.unmodifiable(products);
  }
}

/// Supabase-backed [PharmacyStoreRepository], the pharmacy counterpart of
/// `RestaurantRepository`.
class SupabasePharmacyStoreRepository implements PharmacyStoreRepository {
  const SupabasePharmacyStoreRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<List<PharmacyStore>> fetchStores({String? searchQuery}) async {
    final query = searchQuery?.trim();
    final hasSearch = query != null && query.isNotEmpty;

    var builder = _client
        .from('pharmacy_stores')
        .select('id, name, address')
        .eq('is_active', true);

    if (hasSearch) {
      builder = builder.ilike('name', '%$query%');
    }

    final rows = await builder.order('name');
    return List.unmodifiable(
      rows.map((row) => PharmacyStore.fromMap(Map<String, dynamic>.from(row))),
    );
  }
}

class SupabasePharmacyOrderRepository implements PharmacyOrderRepository {
  const SupabasePharmacyOrderRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<String> placeOrder(PharmacyOrderRequest request) async {
    final response = await _client.rpc<Object?>(
      'place_pharmacy_order',
      params: request.toRpcParams(),
    );
    return requiredRpcId(response, 'pharmacy order');
  }
}
