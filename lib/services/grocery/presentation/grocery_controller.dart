import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/service_module.dart';
import '../../../platform/activity/models/activity_item.dart';
import '../../../platform/activity/presentation/activity_controller.dart';
import '../../../platform/session/session_reset_registry.dart';
import '../data/grocery_repository.dart';
import '../models/grocery_models.dart';

enum GroceryAddResult {
  added,
  quantityIncreased,
  unavailable,
  storeConflict,
  stockLimitReached,
}

class GroceryController extends ChangeNotifier {
  GroceryController({
    required GroceryRepository repository,
    GroceryCatalogRepository? catalogRepository,
    GroceryOrderRepository? orderRepository,
    ActivityController? activityController,
  }) : _repository = repository,
       _catalogRepository =
           catalogRepository ??
           (repository is GroceryCatalogRepository
               ? repository as GroceryCatalogRepository
               : null),
       _orderRepository = orderRepository,
       _activityController = activityController ?? ActivityController.instance;

  // Deliberately does not call load() here: constructing this singleton
  // must not issue catalog queries for users who never open the grocery
  // vertical. Callers (GroceryScreen and friends) trigger load() on demand.
  static final GroceryController instance = () {
    final client = Supabase.instance.client;
    final catalog = SupabaseGroceryCatalogRepository(client: client);
    final controller = GroceryController(
      repository: catalog,
      catalogRepository: catalog,
      orderRepository: SupabaseGroceryOrderRepository(client: client),
    );
    SessionResetRegistry.instance.register(controller.resetSessionState);
    return controller;
  }();

  static const double standardDeliveryFee = 2.50;

  static const List<GroceryDeliverySlot> deliverySlots = [
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

  final GroceryRepository _repository;
  final GroceryCatalogRepository? _catalogRepository;
  final GroceryOrderRepository? _orderRepository;
  final ActivityController _activityController;
  final List<GroceryStore> _stores = [];
  final List<GroceryDeliverySlot> _deliverySlots = [];
  final Map<String, GroceryCartLine> _cart = {};

  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _loadError;
  bool _slotsLoading = false;
  String? _slotLoadError;
  GroceryOrderConfirmation? _lastConfirmation;

  UnmodifiableListView<GroceryStore> get stores =>
      UnmodifiableListView(_stores);
  UnmodifiableListView<GroceryCartLine> get cart =>
      UnmodifiableListView(_cart.values.toList(growable: false));
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get loadError => _loadError;
  bool get slotsLoading => _slotsLoading;
  String? get slotLoadError => _slotLoadError;
  UnmodifiableListView<GroceryDeliverySlot> get availableDeliverySlots =>
      UnmodifiableListView(
        _catalogRepository == null ? deliverySlots : _deliverySlots,
      );
  bool get isEmpty => _cart.isEmpty;
  bool get isNotEmpty => _cart.isNotEmpty;
  int get itemCount => _cart.length;
  GroceryOrderConfirmation? get lastConfirmation => _lastConfirmation;
  String? get storeId =>
      _cart.isEmpty ? null : _cart.values.first.product.storeId;

  String? get storeName {
    final selectedStoreId = storeId;
    if (selectedStoreId == null) {
      return null;
    }
    for (final store in _stores) {
      if (store.id == selectedStoreId) {
        return store.name;
      }
    }
    return null;
  }

  double get subtotal =>
      _cart.values.fold(0, (total, line) => total + line.total);
  double get deliveryFee => _cart.isEmpty ? 0 : standardDeliveryFee;
  double get total => subtotal + deliveryFee;

  Future<void> load() async {
    if (_isLoading) {
      return;
    }
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    try {
      final stores = await _repository.fetchStores();
      _stores
        ..clear()
        ..addAll(stores);
      _hasLoaded = true;
    } on Object {
      _loadError = 'Groceries could not be loaded. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDeliverySlots() async {
    final selectedStoreId = storeId;
    final catalogRepository = _catalogRepository;
    if (selectedStoreId == null || catalogRepository == null || _slotsLoading) {
      return;
    }

    _slotsLoading = true;
    _slotLoadError = null;
    notifyListeners();
    try {
      final slots = await catalogRepository.fetchDeliverySlots(selectedStoreId);
      _deliverySlots
        ..clear()
        ..addAll(slots);
    } on Object {
      _slotLoadError = 'Delivery slots could not be loaded.';
    } finally {
      _slotsLoading = false;
      notifyListeners();
    }
  }

  GroceryAddResult addProduct(
    GroceryProduct product, {
    bool replaceStoreCart = false,
  }) {
    if (!product.isAvailable) {
      return GroceryAddResult.unavailable;
    }

    if (_cart.isNotEmpty && storeId != product.storeId && !replaceStoreCart) {
      return GroceryAddResult.storeConflict;
    }

    if (replaceStoreCart && storeId != product.storeId) {
      _cart.clear();
    }

    final existing = _cart[product.id];
    final nextQuantity = (existing?.quantity ?? 0) + product.quantityStep;
    if (nextQuantity > product.availableQuantity) {
      return GroceryAddResult.stockLimitReached;
    }

    _cart[product.id] = GroceryCartLine(
      product: product,
      quantity: _normalizeQuantity(nextQuantity),
    );
    _lastConfirmation = null;
    notifyListeners();
    return existing == null
        ? GroceryAddResult.added
        : GroceryAddResult.quantityIncreased;
  }

  bool setQuantity(String productId, double quantity) {
    final existing = _cart[productId];
    if (existing == null) {
      return false;
    }

    if (quantity <= 0) {
      _cart.remove(productId);
      notifyListeners();
      return true;
    }

    final product = existing.product;
    final steps = quantity / product.quantityStep;
    final isValidStep = (steps - steps.round()).abs() < 0.0001;
    if (!isValidStep || quantity > product.availableQuantity) {
      return false;
    }

    _cart[productId] = existing.copyWith(
      quantity: _normalizeQuantity(quantity),
    );
    notifyListeners();
    return true;
  }

  bool increment(String productId) {
    final existing = _cart[productId];
    if (existing == null) {
      return false;
    }
    return setQuantity(
      productId,
      existing.quantity + existing.product.quantityStep,
    );
  }

  bool decrement(String productId) {
    final existing = _cart[productId];
    if (existing == null) {
      return false;
    }
    return setQuantity(
      productId,
      existing.quantity - existing.product.quantityStep,
    );
  }

  void remove(String productId) {
    if (_cart.remove(productId) != null) {
      notifyListeners();
    }
  }

  List<String> validateCheckout({
    required GroceryDeliveryAddress address,
    required GroceryDeliverySlot? slot,
    required GrocerySubstitutionPreference? substitutionPreference,
  }) {
    final errors = <String>[];
    if (_cart.isEmpty) {
      errors.add('Add at least one grocery item.');
    }
    if (address.recipientName.trim().isEmpty) {
      errors.add('Enter the recipient name.');
    }
    if (address.phone.trim().length < 7) {
      errors.add('Enter a valid phone number.');
    }
    if (address.street.trim().isEmpty) {
      errors.add('Enter a street or landmark.');
    }
    if (address.district.trim().isEmpty) {
      errors.add('Enter a district.');
    }
    if (address.city.trim().isEmpty) {
      errors.add('Enter a city.');
    }
    if (address.country.trim().toLowerCase() != 'somalia') {
      errors.add('The MVP currently delivers within Somalia only.');
    }
    if (slot == null) {
      errors.add('Choose a delivery slot.');
    }
    if (substitutionPreference == null) {
      errors.add('Choose a substitution preference.');
    }
    return errors;
  }

  Future<GroceryCheckoutResult> confirmOrder({
    required GroceryDeliveryAddress address,
    required GroceryDeliverySlot? slot,
    required GrocerySubstitutionPreference? substitutionPreference,
    DateTime? now,
  }) async {
    final errors = validateCheckout(
      address: address,
      slot: slot,
      substitutionPreference: substitutionPreference,
    );
    if (errors.isNotEmpty) {
      return GroceryCheckoutResult.invalid(errors);
    }

    final createdAt = now ?? DateTime.now();
    String orderId;
    try {
      orderId =
          await _orderRepository?.placeOrder(
            GroceryOrderRequest(
              storeId: storeId!,
              deliverySlotId: slot!.id,
              address: address,
              substitutionPreference: substitutionPreference!,
              items: _cart.values
                  .map(
                    (line) => GroceryOrderLineInput(
                      productId: line.product.id,
                      quantity: line.quantity,
                    ),
                  )
                  .toList(growable: false),
            ),
          ) ??
          'grocery-${createdAt.microsecondsSinceEpoch}';
    } on Object {
      return GroceryCheckoutResult.invalid([
        'The grocery order could not be saved. Please try again.',
      ]);
    }
    final confirmedAmount = total;
    final confirmation = GroceryOrderConfirmation(
      orderId: orderId,
      createdAt: createdAt,
      amount: confirmedAmount,
      slot: slot!,
      address: address,
      substitutionPreference: substitutionPreference!,
    );

    _activityController.record(
      ActivityItem(
        id: orderId,
        serviceId: ServiceId.grocery,
        title: storeName ?? 'Grocery order',
        subtitle: '${slot.label}, ${slot.detail}',
        status: 'Demo confirmed',
        occurredAt: createdAt,
        amount: confirmedAmount,
        detailsRoute: '/grocery',
      ),
    );
    _cart.clear();
    _lastConfirmation = confirmation;
    notifyListeners();
    return GroceryCheckoutResult.confirmed(confirmation);
  }

  @visibleForTesting
  void clear() => resetSessionState();

  void resetSessionState() {
    _cart.clear();
    _deliverySlots.clear();
    _lastConfirmation = null;
    notifyListeners();
  }

  double _normalizeQuantity(double quantity) =>
      (quantity * 100).roundToDouble() / 100;
}
