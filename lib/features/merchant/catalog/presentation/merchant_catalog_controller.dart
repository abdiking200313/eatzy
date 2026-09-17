import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../services/shared/presentation/loadable_state_mixin.dart';
import '../../store/models/merchant_vertical.dart';
import '../data/merchant_catalog_repository.dart';
import '../models/merchant_catalog_item.dart';

/// `ChangeNotifier` controller for the "Catalog" screen (ported from
/// `merchant_app`, originally issue #133, unified into the main app by
/// issue #232), following the same pattern as `MerchantStoreController` and
/// the root app's `GroceryController`.
class MerchantCatalogController extends ChangeNotifier
    with LoadableState, SavableState {
  // These named parameters are constructed directly by tests (e.g.
  // `MerchantCatalogController(repository: FakeMerchantCatalogRepository(),
  // ...)`); initializing formals would force each external name to its
  // private field name, unusable from another file.
  MerchantCatalogController({
    required MerchantCatalogRepository repository,
    required MerchantVertical vertical,
    required String storeId,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _vertical = vertical, // ignore: prefer_initializing_formals
       _storeId = storeId; // ignore: prefer_initializing_formals

  factory MerchantCatalogController.supabase(
    SupabaseClient client, {
    required MerchantVertical vertical,
    required String storeId,
  }) => MerchantCatalogController(
    repository: SupabaseMerchantCatalogRepository(client: client),
    vertical: vertical,
    storeId: storeId,
  );

  final MerchantCatalogRepository _repository;
  final MerchantVertical _vertical;
  final String _storeId;

  final List<MerchantCatalogItem> _items = [];
  final List<PharmacyCategory> _categories = [];
  bool _hasLoaded = false;

  MerchantVertical get vertical => _vertical;
  String get storeId => _storeId;
  UnmodifiableListView<MerchantCatalogItem> get items =>
      UnmodifiableListView(_items);
  UnmodifiableListView<PharmacyCategory> get pharmacyCategories =>
      UnmodifiableListView(_categories);

  /// Whether [load] has completed at least once (regardless of whether any
  /// items were found), distinguishing "still loading" from "loaded, and
  /// this store's catalog is genuinely empty" for the empty state.
  bool get hasLoaded => _hasLoaded;

  Future<void> load() async {
    await runLoad(
      fetch: () async {
        final fetches = <Future<void>>[
          _repository.fetchItems(vertical: _vertical, storeId: _storeId).then((
            fetched,
          ) {
            _items
              ..clear()
              ..addAll(fetched);
          }),
        ];
        if (_vertical == MerchantVertical.pharmacy) {
          fetches.add(
            _repository.fetchPharmacyCategories().then((fetched) {
              _categories
                ..clear()
                ..addAll(fetched);
            }),
          );
        }
        await Future.wait(fetches);
        _hasLoaded = true;
      },
      onError: (error, stackTrace) {
        debugPrint(
          'MerchantCatalogController.load failed: $error\n$stackTrace',
        );
        return 'Your catalog could not be loaded. Please try again.';
      },
    );
  }

  Future<bool> createItem(MerchantCatalogItem draft) {
    return runSave(
      mutate: () async {
        final created = await _repository.createItem(draft);
        _items.add(created);
        _items.sort((a, b) => a.name.compareTo(b.name));
      },
      onError: (error, stackTrace) {
        debugPrint(
          'MerchantCatalogController.createItem failed: $error\n$stackTrace',
        );
        return 'The item could not be added. Please try again.';
      },
    );
  }

  Future<bool> updateItem(MerchantCatalogItem item) {
    return runSave(
      mutate: () async {
        final updated = await _repository.updateItem(item);
        final index = _items.indexWhere((existing) => existing.id == item.id);
        if (index == -1) {
          _items.add(updated);
        } else {
          _items[index] = updated;
        }
        _items.sort((a, b) => a.name.compareTo(b.name));
      },
      onError: (error, stackTrace) {
        debugPrint(
          'MerchantCatalogController.updateItem failed: $error\n$stackTrace',
        );
        return 'The item could not be saved. Please try again.';
      },
    );
  }

  Future<bool> deleteItem(MerchantCatalogItem item) {
    return runSave(
      mutate: () async {
        await _repository.deleteItem(vertical: item.vertical, itemId: item.id);
        _items.removeWhere((existing) => existing.id == item.id);
      },
      onError: (error, stackTrace) {
        debugPrint(
          'MerchantCatalogController.deleteItem failed: $error\n$stackTrace',
        );
        return 'The item could not be deleted. Please try again.';
      },
    );
  }

  Future<bool> toggleAvailability(MerchantCatalogItem item) {
    final nextAvailability = !item.isAvailable;
    return runSave(
      mutate: () async {
        final updated = await _repository.setAvailability(
          item: item,
          isAvailable: nextAvailability,
        );
        final index = _items.indexWhere((existing) => existing.id == item.id);
        if (index != -1) {
          _items[index] = updated;
        }
      },
      onError: (error, stackTrace) {
        debugPrint(
          'MerchantCatalogController.toggleAvailability failed: '
          '$error\n$stackTrace',
        );
        return 'Availability could not be updated. Please try again.';
      },
    );
  }
}
