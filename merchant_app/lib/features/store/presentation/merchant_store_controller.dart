import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../platform/loadable_state.dart';
import '../data/merchant_store_repository.dart';
import '../models/merchant_store.dart';
import '../models/merchant_vertical.dart';

/// `ChangeNotifier` controller for the "My Store" screen (issue #133),
/// following this repo's existing pattern (see the root app's
/// `lib/services/grocery/presentation/grocery_controller.dart`): a
/// `ChangeNotifier` with an injected Supabase-backed repository, not a new
/// state-management framework.
class MerchantStoreController extends ChangeNotifier
    with LoadableState, SavableState {
  // `repository` is a named parameter tests construct directly (e.g.
  // `MerchantStoreController(repository: FakeMerchantStoreRepository())`);
  // an initializing formal would force the external name to the private
  // `_repository`, unusable from another file.
  MerchantStoreController({required MerchantStoreRepository repository})
    // ignore: prefer_initializing_formals
    : _repository = repository;

  factory MerchantStoreController.supabase(SupabaseClient client) =>
      MerchantStoreController(
        repository: SupabaseMerchantStoreRepository(client: client),
      );

  final MerchantStoreRepository _repository;

  MerchantStore? _store;
  bool _hasLoaded = false;

  /// The signed-in merchant's own store, or `null` if not loaded yet, or if
  /// loaded and the merchant has no store in any vertical.
  MerchantStore? get store => _store;

  /// Whether [load] has completed at least once (regardless of whether a
  /// store was found), distinguishing "still loading" from "loaded, and the
  /// merchant genuinely has no store yet" for the empty state.
  bool get hasLoaded => _hasLoaded;

  Future<void> load(String ownerId) async {
    await runLoad(
      fetch: () async {
        _store = await _repository.fetchOwnStore(ownerId);
        _hasLoaded = true;
      },
      onError: (error, stackTrace) {
        debugPrint('MerchantStoreController.load failed: $error\n$stackTrace');
        return 'Your store could not be loaded. Please try again.';
      },
    );
  }

  /// Creates a new store for the merchant in [vertical], for the "no store
  /// yet" empty state. Returns `true` on success.
  Future<bool> createStore({
    required MerchantVertical vertical,
    required String ownerId,
    required String name,
    required String location,
    String? description,
  }) {
    return runSave(
      mutate: () async {
        _store = await _repository.createStore(
          vertical: vertical,
          ownerId: ownerId,
          name: name,
          location: location,
          description: description,
        );
      },
      onError: (error, stackTrace) {
        debugPrint(
          'MerchantStoreController.createStore failed: $error\n$stackTrace',
        );
        return 'Your store could not be created. Please try again.';
      },
    );
  }

  /// Saves edits to the already-loaded store. Returns `true` on success.
  Future<bool> updateStore({
    required String ownerId,
    required String name,
    required String location,
    required bool isOpen,
    String? description,
    String? imageUrl,
  }) {
    final currentStore = _store;
    if (currentStore == null) {
      return Future.value(false);
    }
    return runSave(
      mutate: () async {
        _store = await _repository.updateStore(
          currentStore,
          ownerId: ownerId,
          name: name,
          location: location,
          isOpen: isOpen,
          description: description,
          imageUrl: imageUrl,
        );
      },
      onError: (error, stackTrace) {
        debugPrint(
          'MerchantStoreController.updateStore failed: $error\n$stackTrace',
        );
        return 'Your store could not be saved. Please try again.';
      },
    );
  }
}
