import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/data/rpc_helpers.dart';
import '../models/pharmacy_checkout.dart';
import '../models/pharmacy_product.dart';

abstract interface class PharmacyRepository {
  Future<List<PharmacyProduct>> fetchProducts();
}

abstract interface class PharmacyCatalogRepository {
  Future<List<PharmacyCategory>> fetchCategories();

  Future<List<PharmacyProduct>> fetchProducts();
}

abstract interface class PharmacyOrderRepository {
  Future<String> placeOrder(PharmacyOrderRequest request);
}

class SeededPharmacyRepository implements PharmacyRepository {
  const SeededPharmacyRepository();

  static const products = <PharmacyProduct>[
    PharmacyProduct(
      id: 'pain-paracetamol',
      name: 'Paracetamol',
      description: 'Everyday relief for mild pain and fever.',
      category: 'Pain relief',
      unitPrice: 2.75,
      stockQuantity: 24,
      saleType: PharmacySaleType.overTheCounter,
    ),
    PharmacyProduct(
      id: 'cold-cough-syrup',
      name: 'Cough Syrup',
      description: 'Soothing syrup for common cough symptoms.',
      category: 'Cold & flu',
      unitPrice: 5.50,
      stockQuantity: 4,
      saleType: PharmacySaleType.overTheCounter,
    ),
    PharmacyProduct(
      id: 'first-aid-bandages',
      name: 'Adhesive Bandages',
      description: 'A pack of 30 sterile everyday bandages.',
      category: 'First aid',
      unitPrice: 3.25,
      stockQuantity: 18,
      saleType: PharmacySaleType.overTheCounter,
    ),
    PharmacyProduct(
      id: 'wellness-vitamin-c',
      name: 'Vitamin C',
      description: 'Thirty 500 mg vitamin C tablets.',
      category: 'Vitamins',
      unitPrice: 6.00,
      stockQuantity: 10,
      saleType: PharmacySaleType.overTheCounter,
    ),
    PharmacyProduct(
      id: 'allergy-antihistamine',
      name: 'Allergy Relief',
      description: 'Non-drowsy tablets for common allergy symptoms.',
      category: 'Allergy',
      unitPrice: 4.80,
      stockQuantity: 0,
      saleType: PharmacySaleType.overTheCounter,
    ),
  ];

  @override
  Future<List<PharmacyProduct>> fetchProducts() async {
    return List<PharmacyProduct>.unmodifiable(products);
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
  Future<List<PharmacyProduct>> fetchProducts() async {
    final rows = await _client
        .from('pharmacy_products')
        .select(
          'id, name, description, unit_price, stock_quantity, sale_type, '
          'pharmacy_categories!inner(id, name)',
        )
        .eq('is_active', true)
        .eq('sale_type', 'otc')
        .eq('pharmacy_categories.is_active', true)
        .order('name');

    final products = rows
        .map((row) => PharmacyProduct.fromMap(Map<String, dynamic>.from(row)))
        .where((product) => product.isOverTheCounter)
        .toList(growable: false);
    return List.unmodifiable(products);
  }
}

class SupabasePharmacyOrderRepository implements PharmacyOrderRepository {
  const SupabasePharmacyOrderRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<String> placeOrder(PharmacyOrderRequest request) async {
    final response = await _client.rpc(
      'place_pharmacy_order',
      params: request.toRpcParams(),
    );
    return requiredRpcId(response, 'pharmacy order');
  }
}
