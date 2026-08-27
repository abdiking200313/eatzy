import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/services/pharmacy/data/pharmacy_repository.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_checkout.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_product.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ActivityController activityController;
  late PharmacyController controller;

  setUp(() async {
    activityController = ActivityController();
    controller = PharmacyController(
      repository: const SeededPharmacyRepository(),
      activityController: activityController,
      now: () => DateTime.utc(2026, 7, 27, 12),
    );
    await controller.loadProducts();
  });

  test('pharmacy cart adds, adjusts, removes, and calculates USD totals', () {
    final paracetamol = controller.products.first;

    expect(controller.addProduct(paracetamol), PharmacyCartAddResult.added);
    expect(
      controller.addProduct(paracetamol),
      PharmacyCartAddResult.quantityIncreased,
    );

    expect(controller.cartItems, hasLength(1));
    expect(controller.itemCount, 2);
    expect(controller.subtotal, 5.50);
    expect(controller.total, 8.00);

    controller.decrement(paracetamol.id);
    expect(controller.cartItems.single.quantity, 1);

    controller.removeProduct(paracetamol.id);
    expect(controller.isCartEmpty, isTrue);
    expect(controller.total, 0);
  });

  test('an unavailable OTC product cannot be added', () {
    final unavailable = controller.products.firstWhere(
      (product) => !product.isAvailable,
    );

    expect(
      controller.addProduct(unavailable),
      PharmacyCartAddResult.unavailable,
    );
    expect(controller.isCartEmpty, isTrue);
  });

  test('a non-OTC product is rejected by the domain controller', () {
    const prescriptionProduct = PharmacyProduct(
      id: 'prescription-only',
      name: 'Prescription medicine',
      description: 'Not eligible for the OTC launch.',
      category: 'Prescription',
      unitPrice: 10,
      stockQuantity: 5,
      saleType: PharmacySaleType.prescriptionOnly,
    );

    expect(
      controller.addProduct(prescriptionProduct),
      PharmacyCartAddResult.notOverTheCounter,
    );
    expect(controller.isCartEmpty, isTrue);
  });

  test('checkout validates cart and Somalia delivery details', () {
    const emptyDetails = PharmacyCheckoutDetails(
      customerName: '',
      phoneNumber: '12',
      city: '',
      district: '',
      addressLine: '',
    );

    final validation = controller.validateCheckout(emptyDetails);

    expect(validation.isValid, isFalse);
    expect(validation.errorFor('cart'), isNotNull);
    expect(validation.errorFor('customerName'), isNotNull);
    expect(validation.errorFor('phoneNumber'), isNotNull);
    expect(validation.errorFor('city'), contains('Somalia'));
    expect(validation.errorFor('district'), isNotNull);
    expect(validation.errorFor('addressLine'), isNotNull);
    expect(PharmacyCheckoutDetails.country, 'Somalia');
  });

  test('demo checkout records pharmacy activity and clears its cart', () async {
    controller.addProduct(controller.products.first);
    const details = PharmacyCheckoutDetails(
      customerName: 'Asha Ali',
      phoneNumber: '+252 61 234 5678',
      city: 'Mogadishu',
      district: 'Hodan',
      addressLine: 'Taleex Road, blue gate',
      deliveryInstructions: 'Please call on arrival.',
    );

    final result = await controller.placeDemoOrder(details);

    expect(result.isSuccess, isTrue);
    expect(result.message, contains('No payment was processed'));
    expect(controller.isCartEmpty, isTrue);
    expect(activityController.items, hasLength(1));
    expect(activityController.items.single.serviceId, ServiceId.pharmacy);
    expect(activityController.items.single.status, 'Demo confirmed');
    expect(activityController.items.single.amount, 5.25);
  });

  group('catalog staleness and pull-to-refresh', () {
    test(
      'loadProducts does not refetch an already-loaded, fresh catalog',
      () async {
        final repository = _CountingPharmacyRepository();
        final now = DateTime.utc(2026, 8, 27, 12);
        final freshController = PharmacyController(
          repository: repository,
          activityController: ActivityController(),
          now: () => now,
        );

        await freshController.loadProducts();
        expect(repository.fetchCount, 1);

        await freshController.loadProducts();
        expect(
          repository.fetchCount,
          1,
          reason: 'a fresh catalog should not be refetched',
        );
      },
    );

    test('loadProducts refetches once the catalog goes stale', () async {
      final repository = _CountingPharmacyRepository();
      var now = DateTime.utc(2026, 8, 27, 12);
      final staleController = PharmacyController(
        repository: repository,
        activityController: ActivityController(),
        now: () => now,
      );

      await staleController.loadProducts();
      expect(repository.fetchCount, 1);
      expect(staleController.isStale, isFalse);

      now = now.add(PharmacyController.catalogStaleAfter);
      expect(staleController.isStale, isTrue);

      await staleController.loadProducts();
      expect(repository.fetchCount, 2);
      expect(staleController.isStale, isFalse);
    });

    test(
      'loadProducts(forceRefresh: true) always refetches regardless of staleness',
      () async {
        final repository = _CountingPharmacyRepository();
        final now = DateTime.utc(2026, 8, 27, 12);
        final forcedController = PharmacyController(
          repository: repository,
          activityController: ActivityController(),
          now: () => now,
        );

        await forcedController.loadProducts();
        expect(repository.fetchCount, 1);

        await forcedController.loadProducts(forceRefresh: true);
        expect(repository.fetchCount, 2);
      },
    );
  });
}

class _CountingPharmacyRepository implements PharmacyRepository {
  int fetchCount = 0;

  @override
  Future<List<PharmacyProduct>> fetchProducts() async {
    fetchCount++;
    return const SeededPharmacyRepository().fetchProducts();
  }
}
