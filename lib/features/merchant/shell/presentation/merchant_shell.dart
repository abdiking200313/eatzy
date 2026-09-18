import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/app_routes.dart';
import '../../../../app/merchant_session_gate.dart';
import '../../../auth/data/auth_service.dart';
import '../../admin/presentation/admin_accounts_controller.dart';
import '../../admin/presentation/admin_accounts_screen.dart';
import '../../orders/data/merchant_orders_repository.dart';
import '../../orders/presentation/orders_screen.dart';
import '../../store/presentation/merchant_store_controller.dart';
import '../../store/presentation/my_store_screen.dart';

/// The merchant dashboard's post-sign-in navigation shell (issue #232,
/// ported from the standalone `merchant_app`'s `MerchantShell`, originally
/// issue #132): a bottom nav with "My Store" (real store/catalog
/// management, originally issue #133) and "Orders" (the incoming-order
/// queue and fulfillment screens, originally issue #134), plus a third
/// "Accounts" destination (role management, requested 2026-09-18) visible
/// only to an `admin` account -- see [MerchantSessionGate.isAdmin].
///
/// Reached as an ordinary protected `GoRoute` (`AppRoutes.merchantDashboard`)
/// once [AppRouter] has already decided -- right after sign-in, or on
/// session-restore at app start -- that the signed-in account's
/// `profiles.role` is `merchant`/`admin`. There is no separate merchant
/// sign-in flow any more: the main app's own [AuthService] is reused for
/// sign-out here exactly as every other authenticated screen uses it.
class MerchantShell extends StatefulWidget {
  const MerchantShell({
    super.key,
    this.ownerId,
    this.authService,
    this.myStoreController,
    this.ordersRepository,
    this.isAdmin,
    this.adminAccountsController,
  });

  /// The signed-in merchant's `profiles.id` (== `auth.uid()`). Overridable
  /// for tests; defaults to the current Supabase session's user id.
  final String? ownerId;

  /// Overridable for tests; defaults to a real [AuthService].
  final AuthService? authService;

  /// Overridable for tests, shared between [MyStoreScreen] and
  /// [OrdersScreen] so "my store" is only ever resolved once; defaults to a
  /// real Supabase-backed controller.
  final MerchantStoreController? myStoreController;

  /// Overridable for tests, forwarded to [OrdersScreen]; defaults to a real
  /// Supabase-backed repository.
  final MerchantOrdersRepository? ordersRepository;

  /// Whether to show the "Accounts" role-management destination (requested
  /// directly by the app owner, 2026-09-18). Overridable for tests; defaults
  /// to [MerchantSessionGate.isAdmin], since a plain `merchant` account
  /// should never see it.
  final bool? isAdmin;

  /// Overridable for tests, forwarded to [AdminAccountsScreen] when
  /// [isAdmin] is `true`; defaults to a real Supabase-backed controller.
  /// Only ever constructed (real or fake) when the "Accounts" destination
  /// actually renders -- a plain merchant is never asked to stand one up.
  final AdminAccountsController? adminAccountsController;

  @override
  State<MerchantShell> createState() => _MerchantShellState();
}

class _MerchantShellState extends State<MerchantShell> {
  AuthService get _authService => widget.authService ?? AuthService();

  late final String _ownerId =
      widget.ownerId ?? Supabase.instance.client.auth.currentUser!.id;

  late final MerchantStoreController _storeController =
      widget.myStoreController ??
      MerchantStoreController.supabase(Supabase.instance.client);
  late final bool _ownsStoreController = widget.myStoreController == null;

  late final bool _isAdmin = widget.isAdmin ?? MerchantSessionGate.isAdmin;

  int _selectedIndex = 0;

  late final List<Widget> _destinations = [
    MyStoreScreen(ownerId: _ownerId, controller: _storeController),
    OrdersScreen(
      ownerId: _ownerId,
      storeController: _storeController,
      ordersRepository: widget.ordersRepository,
    ),
    if (_isAdmin)
      AdminAccountsScreen(controller: widget.adminAccountsController),
  ];

  Future<void> _signOut() async {
    await _authService.signOut();
    if (mounted) context.go(AppRoutes.login);
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
            onPressed: () => unawaited(_signOut()),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _destinations),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'My Store',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
          if (_isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings_rounded),
              label: 'Accounts',
            ),
        ],
      ),
    );
  }
}
