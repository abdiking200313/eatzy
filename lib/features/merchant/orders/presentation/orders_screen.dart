import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../platform/localization/app_money.dart';
import '../../store/models/merchant_store.dart';
import '../../store/presentation/merchant_store_controller.dart';
import '../data/merchant_orders_repository.dart';
import '../models/merchant_order.dart';
import '../models/merchant_order_vertical.dart';
import 'merchant_orders_controller.dart';
import 'order_detail_screen.dart';

/// "Orders" screen (ported from `merchant_app`, originally issue #134,
/// unified into the main app by issue #232): the signed-in merchant's
/// incoming-order queue for their own store, newest first, with
/// pull-to-refresh and explicit loading/empty/error states. Reuses
/// [MerchantStoreController] (issue #133) to resolve "my store" instead of
/// re-deriving that logic -- a merchant is modeled as owning at most one
/// store, per that issue's own assumption.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    super.key,
    required this.ownerId,
    this.storeController,
    this.ordersRepository,
  });

  /// The signed-in merchant's `profiles.id` (== `auth.uid()`).
  final String ownerId;

  /// Overridable for tests, and shared with the "My Store" tab by
  /// `MerchantShell` so the store is only ever fetched once; defaults to a
  /// real Supabase-backed controller.
  final MerchantStoreController? storeController;

  /// Overridable for tests; defaults to a real Supabase-backed repository.
  final MerchantOrdersRepository? ordersRepository;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late final MerchantStoreController _storeController =
      widget.storeController ??
      MerchantStoreController.supabase(Supabase.instance.client);
  late final bool _ownsStoreController = widget.storeController == null;

  MerchantOrdersController? _ordersController;

  @override
  void initState() {
    super.initState();
    // Start the load before attaching the listener -- see
    // `MyStoreScreen.initState`'s comment (issue #133) for why the order
    // matters: `load`'s synchronous prefix runs immediately, and calling
    // `setState` that early would throw.
    if (!_storeController.hasLoaded && !_storeController.isLoading) {
      unawaited(_storeController.load(widget.ownerId));
    }
    _storeController.addListener(_onStoreChanged);
    // The store controller may be shared with the "My Store" tab and
    // already loaded by the time this screen builds (e.g. switching tabs
    // after "My Store" finished loading first).
    _maybeCreateOrdersController();
  }

  @override
  void dispose() {
    _storeController.removeListener(_onStoreChanged);
    if (_ownsStoreController) {
      _storeController.dispose();
    }
    _ordersController?.removeListener(_onOrdersChanged);
    _ordersController?.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    _maybeCreateOrdersController();
    setState(() {});
  }

  void _onOrdersChanged() => setState(() {});

  void _maybeCreateOrdersController() {
    if (_ordersController != null) return;
    final store = _storeController.store;
    if (store == null) return;
    final controller = MerchantOrdersController(
      repository:
          widget.ordersRepository ??
          SupabaseMerchantOrdersRepository(client: Supabase.instance.client),
      vertical: store.vertical,
      storeId: store.id,
    );
    _ordersController = controller;
    controller.addListener(_onOrdersChanged);
    unawaited(controller.load());
  }

  @override
  Widget build(BuildContext context) {
    if (_storeController.isLoading && !_storeController.hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final storeLoadError = _storeController.loadError;
    if (storeLoadError != null && _storeController.store == null) {
      return _ErrorView(
        message: storeLoadError,
        onRetry: () => unawaited(_storeController.load(widget.ownerId)),
      );
    }

    final store = _storeController.store;
    if (store == null) {
      return const _NoStoreView();
    }

    final ordersController = _ordersController;
    if (ordersController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return _OrdersListView(controller: ordersController, store: store);
  }
}

class _NoStoreView extends StatelessWidget {
  const _NoStoreView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 48,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'Set up your store first',
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Set up your store from the "My Store" tab to start '
              'receiving orders.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _OrdersListView extends StatelessWidget {
  const _OrdersListView({required this.controller, required this.store});

  final MerchantOrdersController controller;
  final MerchantStore store;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              store.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        Expanded(child: _body(context)),
      ],
    );
  }

  Widget _body(BuildContext context) {
    if (controller.isLoading && !controller.hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final loadError = controller.loadError;
    if (loadError != null && controller.orders.isEmpty) {
      return _ErrorView(
        message: loadError,
        onRetry: () => unawaited(controller.load()),
      );
    }

    if (controller.hasLoaded && controller.orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: controller.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 96),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: Theme.of(context).disabledColor,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No orders yet',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pull down to refresh once a customer places an '
                      'order.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: controller.orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final order = controller.orders[index];
          return _OrderTile(
            order: order,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => OrderDetailScreen(
                  controller: controller,
                  orderId: order.id,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.onTap});

  final MerchantOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final itemsSummary = order.items.isEmpty
        ? 'No items'
        : order.items
              .map((item) => '${item.quantity}x ${item.name}')
              .join(', ');
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text('Order #${shortOrderId(order.id)}'),
        subtitle: Text(
          itemsSummary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _StatusChip(status: order.status),
            const SizedBox(height: 4),
            Text(AppMoney.formatCents(order.totalCents)),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isTerminal = status == 'delivered' || status == 'cancelled';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isTerminal
            ? scheme.surfaceContainerHighest
            : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        merchantOrderStatusLabel(status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isTerminal
              ? scheme.onSurfaceVariant
              : scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
