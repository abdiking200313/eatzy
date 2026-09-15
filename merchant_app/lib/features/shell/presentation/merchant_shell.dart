import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/merchant_auth_service.dart';
import '../../orders/data/merchant_orders_repository.dart';
import '../../orders/presentation/orders_screen.dart';
import '../../store/presentation/merchant_store_controller.dart';
import '../../store/presentation/my_store_screen.dart';

/// Post-sign-in navigation shell (issue #132): a bottom nav with two
/// destinations, "My Store" (real store/catalog management, issue #133) and
/// "Orders" (the incoming-order queue and fulfillment screens, issue #134).
class MerchantShell extends StatefulWidget {
  const MerchantShell({
    super.key,
    required this.user,
    required this.onSignedOut,
    this.authService,
    this.myStoreController,
    this.ordersRepository,
  });

  final User user;
  final VoidCallback onSignedOut;

  /// Overridable for tests; defaults to a real [MerchantAuthService].
  final MerchantAuthService? authService;

  /// Overridable for tests, shared between [MyStoreScreen] and
  /// [OrdersScreen] so "my store" is only ever resolved once; defaults to a
  /// real Supabase-backed controller.
  final MerchantStoreController? myStoreController;

  /// Overridable for tests, forwarded to [OrdersScreen]; defaults to a real
  /// Supabase-backed repository.
  final MerchantOrdersRepository? ordersRepository;

  @override
  State<MerchantShell> createState() => _MerchantShellState();
}

class _MerchantShellState extends State<MerchantShell> {
  MerchantAuthService get _authService =>
      widget.authService ?? MerchantAuthService();

  late final MerchantStoreController _storeController =
      widget.myStoreController ??
      MerchantStoreController.supabase(Supabase.instance.client);
  late final bool _ownsStoreController = widget.myStoreController == null;

  int _selectedIndex = 0;

  late final List<Widget> _destinations = [
    MyStoreScreen(ownerId: widget.user.id, controller: _storeController),
    OrdersScreen(
      ownerId: widget.user.id,
      storeController: _storeController,
      ordersRepository: widget.ordersRepository,
    ),
  ];

  Future<void> _signOut() async {
    await _authService.signOut();
    widget.onSignedOut();
  }

  @override
  void dispose() {
    if (_ownsStoreController) {
      _storeController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zivo Merchant'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _destinations),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'My Store',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
        ],
      ),
    );
  }
}
