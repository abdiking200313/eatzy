import 'dart:convert';

import 'package:chowflow/app/app_routes.dart';
import 'package:chowflow/features/auth/data/auth_service.dart';
import 'package:chowflow/features/merchant/shell/presentation/merchant_shell.dart';
import 'package:chowflow/features/merchant/store/presentation/merchant_store_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/fake_merchant_repositories.dart';

// Smoke-tests the merchant dashboard's nav shell (ported from
// `merchant_app`'s `merchant_shell_test.dart`, originally issue #132,
// unified into the main app by issue #232): it must land on real routed
// "My Store" (originally issue #133) / "Orders" (originally issue #134)
// destinations, sharing one `MerchantStoreController` between them, and
// switching tabs must actually switch content. Both are given a fake,
// no-store-yet repository so this stays a pure widget test with no
// Supabase network access.
void main() {
  MerchantStoreController fakeStoreController() =>
      MerchantStoreController(repository: FakeMerchantStoreRepository());

  testWidgets('shows "My Store" destination by default', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantShell(
          ownerId: 'merchant-1',
          myStoreController: fakeStoreController(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Store'), findsWidgets);
    expect(find.text('Orders'), findsWidgets);
    // No store yet for this fake merchant -- the empty/create-store state.
    expect(find.text("You don't have a store yet"), findsOneWidget);
  });

  testWidgets('switching to Orders shows the Orders destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantShell(
          ownerId: 'merchant-1',
          myStoreController: fakeStoreController(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Orders'));
    await tester.pumpAndSettle();

    // No store yet for this fake merchant -- Orders shows its own "set up
    // your store first" empty state, resolved from the same shared
    // `MerchantStoreController` "My Store" also uses.
    expect(find.text('Set up your store first'), findsOneWidget);
  });

  testWidgets(
    'signing out calls AuthService.signOut and returns to login (issue #232)',
    (tester) async {
      // Same PKCE/implicit-flow test setup as `test/auth_service_test.dart`:
      // establishes a real session against a mocked Supabase auth server so
      // signing out is exercised end-to-end, not just the navigation.
      const testAuthOptions = AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        autoRefreshToken: false,
      );
      final mockClient = MockClient((request) async {
        if (request.url.path == '/auth/v1/logout') {
          return http.Response('', 204);
        }
        final now = DateTime.now().toIso8601String();
        return http.Response(
          jsonEncode({
            'access_token': 'mock-access-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'mock-refresh-token',
            'user': {
              'id': 'merchant-1',
              'aud': 'authenticated',
              'email': 'owner@example.com',
              'app_metadata': <String, dynamic>{},
              'user_metadata': <String, dynamic>{},
              'created_at': now,
            },
          }),
          200,
        );
      });
      final supabaseClient = SupabaseClient(
        'https://example.supabase.co',
        'test-publishable-key',
        authOptions: testAuthOptions,
        httpClient: mockClient,
      );
      final authService = AuthService(client: supabaseClient);
      await authService.signInWithEmailPassword(
        'owner@example.com',
        'password123',
      );

      final router = GoRouter(
        initialLocation: AppRoutes.merchantDashboard,
        routes: [
          GoRoute(
            path: AppRoutes.merchantDashboard,
            builder: (_, _) => MerchantShell(
              ownerId: 'merchant-1',
              authService: authService,
              myStoreController: fakeStoreController(),
            ),
          ),
          GoRoute(
            path: AppRoutes.login,
            builder: (_, _) => const Scaffold(body: Text('login screen')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();

      expect(authService.getCurrentUserId(), isNull);
      expect(find.text('login screen'), findsOneWidget);
    },
  );
}
