import 'dart:async';

import 'package:chowflow/app/app_router.dart';
import 'package:chowflow/app/app_routes.dart';
import 'package:chowflow/app/merchant_session_gate.dart';
import 'package:chowflow/features/merchant/auth/data/merchant_role_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Answers `fetchRole` with [role], optionally holding the answer back until
/// [gate] completes so a test can observe what happens while the lookup is
/// still in flight.
class _FakeRoleService implements MerchantRoleService {
  _FakeRoleService(this.role, {this.gate});

  final String? role;
  final Completer<void>? gate;
  int calls = 0;

  @override
  Future<String?> fetchRole(String userId) async {
    calls++;
    await gate?.future;
    return role;
  }

  @override
  Future<bool> isMerchantAccount(String userId) async =>
      isAuthorizedMerchantRole(await fetchRole(userId));
}

// The role decides whether a signed-in account lands on the merchant
// dashboard or the customer home, so it must be known *before* the router
// answers -- otherwise a merchant/admin sees the customer home flash by while
// the lookup is still running (reported by the app owner, 2026-09-18).
void main() {
  setUp(MerchantSessionGate.reset);
  tearDown(MerchantSessionGate.reset);

  group('MerchantSessionGate.resolveFor', () {
    test('caches a merchant and an admin role', () async {
      await MerchantSessionGate.resolveFor(
        'm-1',
        roleService: _FakeRoleService('merchant'),
      );
      expect(MerchantSessionGate.isMerchantRole, isTrue);
      expect(MerchantSessionGate.isAdmin, isFalse);
      expect(MerchantSessionGate.resolvedUserId, 'm-1');

      MerchantSessionGate.reset();
      await MerchantSessionGate.resolveFor(
        'a-1',
        roleService: _FakeRoleService('admin'),
      );
      expect(MerchantSessionGate.isMerchantRole, isTrue);
      expect(MerchantSessionGate.isAdmin, isTrue);
    });

    test('a customer or failed lookup resolves as a plain customer', () async {
      await MerchantSessionGate.resolveFor(
        'c-1',
        roleService: _FakeRoleService('customer'),
      );
      expect(MerchantSessionGate.isMerchantRole, isFalse);
      expect(MerchantSessionGate.resolvedUserId, 'c-1');

      MerchantSessionGate.reset();
      await MerchantSessionGate.resolveFor(
        'c-2',
        roleService: _FakeRoleService(null),
      );
      expect(MerchantSessionGate.isMerchantRole, isFalse);
      expect(MerchantSessionGate.resolvedUserId, 'c-2');
    });

    test('does not look the same user up twice', () async {
      final service = _FakeRoleService('merchant');
      await MerchantSessionGate.resolveFor('m-1', roleService: service);
      await MerchantSessionGate.resolveFor('m-1', roleService: service);

      expect(service.calls, 1);
    });

    test('concurrent callers share one in-flight lookup', () async {
      final gate = Completer<void>();
      final service = _FakeRoleService('merchant', gate: gate);

      final first = MerchantSessionGate.resolveFor('m-1', roleService: service);
      final second = MerchantSessionGate.resolveFor(
        'm-1',
        roleService: service,
      );
      gate.complete();
      await Future.wait([first, second]);

      expect(service.calls, 1);
      expect(MerchantSessionGate.isMerchantRole, isTrue);
    });

    test('a different user is looked up again', () async {
      await MerchantSessionGate.resolveFor(
        'm-1',
        roleService: _FakeRoleService('merchant'),
      );
      await MerchantSessionGate.resolveFor(
        'c-1',
        roleService: _FakeRoleService('customer'),
      );

      expect(MerchantSessionGate.isMerchantRole, isFalse);
      expect(MerchantSessionGate.resolvedUserId, 'c-1');
    });

    test(
      'a lookup finishing after sign-out cannot repopulate the gate',
      () async {
        final gate = Completer<void>();
        final pending = MerchantSessionGate.resolveFor(
          'm-1',
          roleService: _FakeRoleService('admin', gate: gate),
        );

        MerchantSessionGate.reset(); // signed out while the lookup is running
        gate.complete();
        await pending;

        expect(MerchantSessionGate.isMerchantRole, isFalse);
        expect(MerchantSessionGate.isAdmin, isFalse);
        expect(MerchantSessionGate.resolvedUserId, isNull);
      },
    );
  });

  group('AppRouter.redirectFor', () {
    test(
      'waits for the role, then sends a merchant to the dashboard',
      () async {
        final gate = Completer<void>();
        final result = AppRouter.redirectFor(
          userId: 'm-1',
          location: AppRoutes.login,
          roleService: _FakeRoleService('merchant', gate: gate),
        );

        // Still resolving: no answer yet, in particular not the customer home.
        expect(result, isA<Future<String?>>());
        gate.complete();
        expect(await result, AppRoutes.merchantDashboard);
      },
    );

    test('waits for the role, then sends a customer to the home', () async {
      final result = AppRouter.redirectFor(
        userId: 'c-1',
        location: AppRoutes.login,
        roleService: _FakeRoleService('customer'),
      );

      expect(await result, AppRoutes.mainApp);
    });

    test('answers synchronously once the role is cached', () async {
      await MerchantSessionGate.resolveFor(
        'm-1',
        roleService: _FakeRoleService('merchant'),
      );

      final result = AppRouter.redirectFor(
        userId: 'm-1',
        location: AppRoutes.food,
      );

      expect(result, AppRoutes.merchantDashboard);
    });

    test('signed out never triggers a role lookup', () {
      final service = _FakeRoleService('merchant');

      final result = AppRouter.redirectFor(
        userId: null,
        location: AppRoutes.login,
        roleService: service,
      );

      expect(result, isNull);
      expect(service.calls, 0);
    });
  });

  testWidgets('signing in as a merchant never shows the customer home', (
    tester,
  ) async {
    final gate = Completer<void>();
    final service = _FakeRoleService('merchant', gate: gate);
    final auth = ChangeNotifier();
    addTearDown(auth.dispose);
    String? signedInUserId;
    var customerHomeBuilt = false;

    final router = GoRouter(
      initialLocation: AppRoutes.login,
      refreshListenable: auth,
      redirect: (_, state) => AppRouter.redirectFor(
        userId: signedInUserId,
        location: state.uri.path,
        roleService: service,
      ),
      routes: [
        GoRoute(
          path: AppRoutes.login,
          builder: (_, _) => const Scaffold(body: Text('login screen')),
        ),
        GoRoute(
          path: AppRoutes.mainApp,
          builder: (_, _) {
            customerHomeBuilt = true;
            return const Scaffold(body: Text('customer home'));
          },
        ),
        GoRoute(
          path: AppRoutes.merchantDashboard,
          builder: (_, _) => const Scaffold(body: Text('merchant dashboard')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('login screen'), findsOneWidget);

    // The sign-in event: a session now exists, but the role lookup is still
    // running. The login screen must stay put, not fall through to home.
    signedInUserId = 'm-1';
    // ignore: invalid_use_of_protected_member
    auth.notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('login screen'), findsOneWidget);
    expect(customerHomeBuilt, isFalse);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('merchant dashboard'), findsOneWidget);
    expect(customerHomeBuilt, isFalse);
  });
}
