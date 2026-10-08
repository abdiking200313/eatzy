import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../app/app_scope.dart';
import '../../../../app/merchant_session_gate.dart';
import '../../../../config/tailwind.dart';
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
/// queue and fulfillment screens, originally issue #134).
///
/// An `admin` account (see [MerchantSessionGate.isAdmin]) sees none of
/// that: the shell shows only the "Accounts" role-management list
/// (requested 2026-09-18) plus the sign-out button, with no bottom nav.
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
  /// for tests; defaults to the current Supabase session's user id (from
  /// [AppScope], see issue #285), or `null` if there is somehow no signed-in
  /// user by the time this builds.
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

  /// Whether to show the admin-only "Accounts" role-management screen
  /// *instead of* the merchant destinations (requested directly by the app
  /// owner, 2026-09-18). Overridable for tests; defaults to
  /// [MerchantSessionGate.isAdmin], since a plain `merchant` account should
  /// never see it.
  final bool? isAdmin;

  /// Overridable for tests, forwarded to [AdminAccountsScreen] when
  /// [isAdmin] is `true`; defaults to a real Supabase-backed controller.
  /// Only ever constructed (real or fake) for an admin -- a plain merchant
  /// is never asked to stand one up.
  final AdminAccountsController? adminAccountsController;

  @override
  State<MerchantShell> createState() => _MerchantShellState();
}

class _MerchantShellState extends State<MerchantShell> {
  AuthService get _authService => widget.authService ?? AuthService();

  String? _ownerId;
  MerchantStoreController? _storeController;
  bool _ownsStoreController = false;
  bool _isAdmin = false;
  bool _dependenciesResolved = false;

  int _selectedIndex = 0;

  // Resolved here rather than in field initializers / initState: reading
  // the Supabase client off `AppScope.of(context)` (issue #285) needs a
  // `BuildContext` that is allowed to look up an `InheritedWidget`, which
  // `didChangeDependencies` is and `initState` is not. Guarded by
  // `_dependenciesResolved` so a later dependency change (unlikely here,
  // since `AppServices` itself never changes) never re-creates the
  // controller mid-session.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesResolved) return;
    _dependenciesResolved = true;

    final services = AppScope.of(context);
    _ownerId = widget.ownerId ?? services.supabaseClient.auth.currentUser?.id;
    _isAdmin = widget.isAdmin ?? MerchantSessionGate.isAdmin;

    // Lazy, and never touched for an admin or a missing owner id: an admin
    // sees only the Accounts screen, and a missing owner id means there is
    // no merchant session to resolve "my store" for in the first place (see
    // `build`'s sign-in prompt), so no store controller (or its Supabase
    // queries) is stood up in either case.
    if (!_isAdmin && _ownerId != null) {
      _storeController =
          widget.myStoreController ??
          MerchantStoreController.supabase(services.supabaseClient);
      _ownsStoreController = widget.myStoreController == null;
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  void dispose() {
    if (_ownsStoreController) {
      _storeController?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ownerId = _ownerId;
    // No signed-in user to resolve a merchant/admin session for -- this
    // route is normally only reachable once `AppRouter` has already
    // confirmed a session exists, but a session can still end (e.g. token
    // expiry, manual sign-out from another tab) between that redirect check
    // and this build. Show a safe prompt instead of crashing on a
    // force-unwrapped `currentUser!.id`.
    if (ownerId == null) {
      return _SignedOutView(onSignIn: () => context.go(AppRoutes.login));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isAdmin ? 'Zivo Admin' : 'Zivo Merchant'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => unawaited(_signOut()),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: _isAdmin
          ? AdminAccountsScreen(
              controller: widget.adminAccountsController,
              currentUserId: ownerId,
            )
          : IndexedStack(
              index: _selectedIndex,
              children: [
                MyStoreScreen(ownerId: ownerId, controller: _storeController),
                OrdersScreen(
                  ownerId: ownerId,
                  storeController: _storeController,
                  ordersRepository: widget.ordersRepository,
                ),
              ],
            ),
      bottomNavigationBar: _isAdmin
          ? null
          : NavigationBar(
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

/// Shown instead of the dashboard when there is no signed-in user to resolve
/// a merchant/admin session for (see `_MerchantShellState.build`'s doc
/// comment) -- a safe fallback for the force-unwrap this replaced, not an
/// expected steady state.
class _SignedOutView extends StatelessWidget {
  const _SignedOutView({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(TwSpacing.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 48,
                color: Theme.of(context).disabledColor,
              ),
              const SizedBox(height: TwSpacing.x4),
              const Text(
                'Your session has ended',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: TwSpacing.x1),
              const Text(
                'Sign in again to get back to your store.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: TwSpacing.x6),
              FilledButton(onPressed: onSignIn, child: const Text('Sign in')),
            ],
          ),
        ),
      ),
    );
  }
}
