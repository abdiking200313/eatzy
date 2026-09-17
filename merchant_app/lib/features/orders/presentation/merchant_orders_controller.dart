import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../platform/loadable_state.dart';
import '../../store/models/merchant_vertical.dart';
import '../data/merchant_orders_repository.dart';
import '../models/merchant_order.dart';

/// `ChangeNotifier` controller for the "Orders" screen (issue #134),
/// following the same pattern as `MerchantStoreController` and
/// `MerchantCatalogController` from issue #133.
class MerchantOrdersController extends ChangeNotifier
    with LoadableState, SavableState {
  // These named parameters are constructed directly by tests (e.g.
  // `MerchantOrdersController(repository: FakeMerchantOrdersRepository(),
  // ...)`); initializing formals would force each external name to its
  // private field name, unusable from another file.
  MerchantOrdersController({
    required MerchantOrdersRepository repository,
    required MerchantVertical vertical,
    required String storeId,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _vertical = vertical, // ignore: prefer_initializing_formals
       _storeId = storeId; // ignore: prefer_initializing_formals

  factory MerchantOrdersController.supabase(
    SupabaseClient client, {
    required MerchantVertical vertical,
    required String storeId,
  }) => MerchantOrdersController(
    repository: SupabaseMerchantOrdersRepository(client: client),
    vertical: vertical,
    storeId: storeId,
  );

  final MerchantOrdersRepository _repository;
  final MerchantVertical _vertical;
  final String _storeId;

  final List<MerchantOrder> _orders = [];
  bool _hasLoaded = false;

  MerchantVertical get vertical => _vertical;
  String get storeId => _storeId;
  UnmodifiableListView<MerchantOrder> get orders =>
      UnmodifiableListView(_orders);

  /// Whether [load] has completed at least once (regardless of whether any
  /// orders were found), distinguishing "still loading" from "loaded, and
  /// this store genuinely has no orders yet" for the empty state.
  bool get hasLoaded => _hasLoaded;

  Future<void> load() async {
    await runLoad(
      fetch: () async {
        final fetched = await _repository.fetchOrders(
          vertical: _vertical,
          storeId: _storeId,
        );
        _orders
          ..clear()
          ..addAll(fetched);
        _hasLoaded = true;
      },
      onError: (error, stackTrace) {
        debugPrint('MerchantOrdersController.load failed: $error\n$stackTrace');
        return 'Your orders could not be loaded. Please try again.';
      },
    );
  }

  /// Advances [order] to [newStatus] via the vertical's
  /// `advance_*_order_status` RPC (issue #131) -- accept/reject on a
  /// `confirmed` order, or moving through the rest of the vocabulary.
  /// Returns `true` on success. On failure, [saveError] carries the
  /// server's own rejection message (see
  /// [OrderStatusTransitionException]) so an illegal transition is a clear
  /// error, never a silent no-op.
  Future<bool> advanceStatus(MerchantOrder order, String newStatus) {
    return runSave(
      mutate: () async {
        final updatedStatus = await _repository.advanceOrderStatus(
          vertical: _vertical,
          orderId: order.id,
          newStatus: newStatus,
        );
        final index = _orders.indexWhere((existing) => existing.id == order.id);
        if (index != -1) {
          _orders[index] = _orders[index].copyWith(status: updatedStatus);
        }
      },
      onError: (error, stackTrace) {
        debugPrint(
          'MerchantOrdersController.advanceStatus failed: $error\n$stackTrace',
        );
        if (error is OrderStatusTransitionException) {
          return error.message;
        }
        return 'The order status could not be updated. Please try again.';
      },
    );
  }

  /// The current copy of [orderId] from [orders], or `null` if it is no
  /// longer in the loaded list (e.g. removed by a concurrent refresh).
  MerchantOrder? orderById(String orderId) {
    for (final order in _orders) {
      if (order.id == orderId) return order;
    }
    return null;
  }
}
