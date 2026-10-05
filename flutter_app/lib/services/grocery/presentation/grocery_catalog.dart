import 'dart:collection';

import '../data/grocery_repository.dart';
import '../models/grocery_models.dart';

/// Default delivery slots shown when the injected repository doesn't
/// implement [GroceryCatalogRepository] (e.g. [SeededGroceryRepository] in
/// tests) and so can't fetch real ones -- see
/// [GroceryCatalog.availableDeliverySlots].
const List<GroceryDeliverySlot> defaultGroceryDeliverySlots = [
  GroceryDeliverySlot(
    id: 'today-afternoon',
    label: 'Today',
    detail: '2:00 PM – 4:00 PM',
  ),
  GroceryDeliverySlot(
    id: 'today-evening',
    label: 'Today',
    detail: '6:00 PM – 8:00 PM',
  ),
  GroceryDeliverySlot(
    id: 'tomorrow-morning',
    label: 'Tomorrow',
    detail: '9:00 AM – 11:00 AM',
  ),
];

/// Owns the grocery store/product catalog: which stores have loaded, how
/// stale that load is, and the delivery slots for the currently selected
/// store.
///
/// Extracted from `GroceryController` (issue #293) to separate catalog
/// loading/caching from cart/quantity rules (see `GroceryCart`) and from
/// checkout. [load] and [loadStore] are plain fetch-and-store methods with no
/// loading-state bookkeeping of their own: `GroceryController` wraps them in
/// its own `LoadableState.runLoad` exactly as it did before extraction, so
/// `isLoading`/`loadError` keep working unchanged. [loadDeliverySlots] is the
/// exception -- like before extraction, it manages its own loading flag and
/// calls back into the controller (via [onChanged]) at the same two points,
/// since it was never run through `runLoad`.
class GroceryCatalog {
  GroceryCatalog({
    required GroceryRepository repository,
    required GroceryStoreType storeType,
    GroceryCatalogRepository? catalogRepository,
    DateTime Function()? now,
    required Duration staleAfter,
  }) : _repository = repository,
       _storeType = storeType,
       _catalogRepository =
           catalogRepository ??
           (repository is GroceryCatalogRepository
               ? repository as GroceryCatalogRepository
               : null),
       _now = now ?? DateTime.now,
       _staleAfter = staleAfter;

  final GroceryRepository _repository;
  final GroceryStoreType _storeType;
  final GroceryCatalogRepository? _catalogRepository;
  final DateTime Function() _now;
  final Duration _staleAfter;

  final List<GroceryStore> _stores = [];
  final List<GroceryDeliverySlot> _deliverySlots = [];

  /// Store IDs individually fetched via [loadStore] (as opposed to via the
  /// every-store [load]). Consulted by [hasLoadedStore] so a screen scoped
  /// to one store doesn't need the full multi-store catalog loaded first.
  final Set<String> _loadedStoreIds = {};

  bool _hasLoaded = false;
  DateTime? _lastLoadedAt;
  bool _slotsLoading = false;
  String? _slotLoadError;

  /// Exposed so `GroceryController.loadStore` can fall back to [load] when
  /// this is `null`, exactly as it did before extraction.
  GroceryCatalogRepository? get catalogRepository => _catalogRepository;

  UnmodifiableListView<GroceryStore> get stores =>
      UnmodifiableListView(_stores);
  bool get hasLoaded => _hasLoaded;

  /// Whether [storeId] can be found in [stores]: either the full catalog
  /// has been loaded at least once (via [load]), or that specific store was
  /// individually loaded via [loadStore].
  bool hasLoadedStore(String storeId) =>
      _hasLoaded || _loadedStoreIds.contains(storeId);

  /// Whether the loaded stores/catalog are old enough that a caller should
  /// treat them as needing a refetch: never loaded, or last loaded at least
  /// [_staleAfter] ago.
  bool get isStale {
    final lastLoadedAt = _lastLoadedAt;
    return lastLoadedAt == null ||
        _now().difference(lastLoadedAt) >= _staleAfter;
  }

  bool get slotsLoading => _slotsLoading;
  String? get slotLoadError => _slotLoadError;
  UnmodifiableListView<GroceryDeliverySlot> get availableDeliverySlots =>
      UnmodifiableListView(
        _catalogRepository == null
            ? defaultGroceryDeliverySlots
            : _deliverySlots,
      );

  /// Fetches every active store for this catalog's [_storeType] and
  /// replaces [stores]. Intended to run inside the caller's own
  /// loading-state wrapper (`LoadableState.runLoad`), which is why this
  /// doesn't manage a loading flag or call back into the controller itself.
  Future<void> load() async {
    final stores = await _repository.fetchStores();
    _stores
      ..clear()
      ..addAll(stores.where((store) => store.storeType == _storeType));
    _hasLoaded = true;
    _lastLoadedAt = _now();
  }

  /// Loads a single store (and just its own products), scoped by [storeId].
  /// Falls back to [load] when [catalogRepository] is `null` (e.g.
  /// [SeededGroceryRepository] in tests) -- the full catalog it fetches
  /// already contains every store, this one included.
  Future<void> loadStore(String storeId) async {
    final catalogRepository = _catalogRepository;
    if (catalogRepository == null) {
      return load();
    }
    final store = await catalogRepository.fetchStore(storeId);
    if (store != null) {
      final index = _stores.indexWhere((existing) => existing.id == store.id);
      if (index == -1) {
        _stores.add(store);
      } else {
        _stores[index] = store;
      }
      _loadedStoreIds.add(storeId);
    }
    _lastLoadedAt = _now();
  }

  /// Loads delivery slots for [storeId]. A no-op when [storeId] is `null`,
  /// there's no [catalogRepository] to fetch from, or a load is already in
  /// flight. Calls [onChanged] (the controller's `notifyListeners`) at the
  /// same two points the unextracted method did.
  Future<void> loadDeliverySlots(
    String? storeId, {
    required void Function() onChanged,
  }) async {
    final catalogRepository = _catalogRepository;
    if (storeId == null || catalogRepository == null || _slotsLoading) {
      return;
    }

    _slotsLoading = true;
    _slotLoadError = null;
    onChanged();
    try {
      final slots = await catalogRepository.fetchDeliverySlots(storeId);
      _deliverySlots
        ..clear()
        ..addAll(slots);
    } on Object {
      _slotLoadError = 'Delivery slots could not be loaded.';
    } finally {
      _slotsLoading = false;
      onChanged();
    }
  }

  /// Clears loaded delivery slots. Used by
  /// `GroceryController.resetSessionState` on an account switch.
  void resetDeliverySlots() {
    _deliverySlots.clear();
  }
}
