import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/merchant_auth_service.dart';
import '../../orders/presentation/orders_screen.dart';
import '../../store/presentation/my_store_screen.dart';

/// Minimal post-sign-in navigation shell (issue #132): a bottom nav with
/// two stub destinations, "My Store" and "Orders", filled in by the two
/// child issues (#133/#134) that follow this scaffold.
class MerchantShell extends StatefulWidget {
  const MerchantShell({
    super.key,
    required this.user,
    required this.onSignedOut,
    this.authService,
  });

  final User user;
  final VoidCallback onSignedOut;

  /// Overridable for tests; defaults to a real [MerchantAuthService].
  final MerchantAuthService? authService;

  @override
  State<MerchantShell> createState() => _MerchantShellState();
}

class _MerchantShellState extends State<MerchantShell> {
  MerchantAuthService get _authService =>
      widget.authService ?? MerchantAuthService();

  int _selectedIndex = 0;

  static const _destinations = [MyStoreScreen(), OrdersScreen()];

  Future<void> _signOut() async {
    await _authService.signOut();
    widget.onSignedOut();
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
