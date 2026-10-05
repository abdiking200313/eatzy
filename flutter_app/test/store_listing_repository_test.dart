import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/platform/discovery/store_listing_repository.dart';
import 'package:chowflow/platform/error_reporting/error_reporter.dart';
import 'package:chowflow/services/food/data/restaurant_repository.dart';
import 'package:chowflow/services/food/models/restaurant.dart';
import 'package:chowflow/services/grocery/data/grocery_repository.dart';
import 'package:chowflow/services/grocery/models/grocery_models.dart';
import 'package:chowflow/services/pharmacy/data/pharmacy_repository.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StoreListingRepository (issue #286)', () {
    late ErrorReporter originalReporter;
    late _FakeErrorReporter fakeReporter;

    setUp(() {
      originalReporter = ErrorReporting.instance;
      fakeReporter = _FakeErrorReporter();
      ErrorReporting.instance = fakeReporter;
    });

    tearDown(() {
      ErrorReporting.instance = originalReporter;
    });

    test('when every vertical fails, fetchStores throws instead of silently '
        'returning an empty list, and every failure is reported', () async {
      final repository = StoreListingRepository(
        restaurantRepository: _ThrowingRestaurantRepository(
          StateError('food down'),
        ),
        groceryRepository: _ThrowingGroceryRepository(
          StateError('grocery down'),
        ),
        pharmacyRepository: _ThrowingPharmacyRepository(
          StateError('pharmacy down'),
        ),
      );

      await expectLater(
        repository.fetchStores(),
        throwsA(isA<StoreListingUnavailableException>()),
      );

      expect(fakeReporter.reported, hasLength(3));
      expect(
        fakeReporter.reported.map((r) => r.context),
        containsAll(<String>[
          'StoreListingRepository._fetchFood',
          'StoreListingRepository._fetchGrocery',
          'StoreListingRepository._fetchPharmacy',
        ]),
      );
    });

    test('StoreListingUnavailableException.toString never exposes raw '
        'exception detail -- safe to show directly in the UI', () {
      const exception = StoreListingUnavailableException();
      expect(exception.toString(), isNot(contains('StateError')));
      expect(exception.toString(), isNotEmpty);
    });

    test('when only some verticals fail, fetchStores returns the stores that '
        'did load and still reports just the failures', () async {
      final repository = StoreListingRepository(
        restaurantRepository: _FakeRestaurantRepository(const [
          Restaurant(
            id: 'r1',
            name: 'Pizza Place',
            description: '',
            logoUrl: '',
          ),
        ]),
        groceryRepository: _ThrowingGroceryRepository(
          StateError('grocery down'),
        ),
        pharmacyRepository: _FakePharmacyStoreRepository(const [
          PharmacyStore(id: 'p1', name: 'Downtown Pharmacy', address: ''),
        ]),
      );

      final stores = await repository.fetchStores();

      expect(stores.map((s) => s.id), containsAll(<String>['r1', 'p1']));
      expect(fakeReporter.reported, hasLength(1));
      expect(
        fakeReporter.reported.single.context,
        'StoreListingRepository._fetchGrocery',
      );
    });

    test(
      'a single-vertical filter that fails throws, and is reported',
      () async {
        final repository = StoreListingRepository(
          restaurantRepository: _ThrowingRestaurantRepository(
            StateError('food down'),
          ),
          groceryRepository: _FakeGroceryRepository(const []),
          pharmacyRepository: _FakePharmacyStoreRepository(const []),
        );

        await expectLater(
          repository.fetchStores(filter: ServiceId.food),
          throwsA(isA<StoreListingUnavailableException>()),
        );
        expect(fakeReporter.reported, hasLength(1));
        expect(
          fakeReporter.reported.single.context,
          'StoreListingRepository._fetchFood',
        );
      },
    );

    test('all verticals genuinely empty (no failures) returns an empty list '
        'without throwing, and reports nothing', () async {
      final repository = StoreListingRepository(
        restaurantRepository: _FakeRestaurantRepository(const []),
        groceryRepository: _FakeGroceryRepository(const []),
        pharmacyRepository: _FakePharmacyStoreRepository(const []),
      );

      final stores = await repository.fetchStores();

      expect(stores, isEmpty);
      expect(fakeReporter.reported, isEmpty);
    });
  });
}

class _FakeErrorReporter implements ErrorReporter {
  final List<({Object error, StackTrace stack, String? context})> reported = [];

  @override
  void reportError(Object error, StackTrace stack, {String? context}) {
    reported.add((error: error, stack: stack, context: context));
  }
}

class _FakeRestaurantRepository implements RestaurantRepository {
  _FakeRestaurantRepository(this._restaurants);

  final List<Restaurant> _restaurants;

  @override
  Future<List<Restaurant>> fetchRestaurants({
    String? searchQuery,
    String? categoryId,
    int limit = RestaurantRepository.defaultPageSize,
    int offset = 0,
  }) async => _restaurants;
}

class _ThrowingRestaurantRepository implements RestaurantRepository {
  _ThrowingRestaurantRepository(this._error);

  final Object _error;

  @override
  Future<List<Restaurant>> fetchRestaurants({
    String? searchQuery,
    String? categoryId,
    int limit = RestaurantRepository.defaultPageSize,
    int offset = 0,
  }) async => throw _error;
}

class _FakeGroceryRepository implements GroceryRepository {
  _FakeGroceryRepository(this._stores);

  final List<GroceryStore> _stores;

  @override
  Future<List<GroceryStore>> fetchStores() async => _stores;
}

class _ThrowingGroceryRepository implements GroceryRepository {
  _ThrowingGroceryRepository(this._error);

  final Object _error;

  @override
  Future<List<GroceryStore>> fetchStores() async => throw _error;
}

class _FakePharmacyStoreRepository implements PharmacyStoreRepository {
  _FakePharmacyStoreRepository(this._stores);

  final List<PharmacyStore> _stores;

  @override
  Future<List<PharmacyStore>> fetchStores({String? searchQuery}) async =>
      _stores;
}

class _ThrowingPharmacyRepository implements PharmacyStoreRepository {
  _ThrowingPharmacyRepository(this._error);

  final Object _error;

  @override
  Future<List<PharmacyStore>> fetchStores({String? searchQuery}) async =>
      throw _error;
}
