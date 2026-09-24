import 'dart:convert';

import 'package:chowflow/app/app_routes.dart';
import 'package:chowflow/app/merchant_session_gate.dart';
import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/auth/data/auth_service.dart';
import 'package:chowflow/features/auth/presentation/login_screen.dart';
import 'package:chowflow/features/merchant/auth/data/merchant_role_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('sign-in form', () {
    testWidgets(
      'renders the sign-in form without overflow at 320x640 with a 1.4x '
      'text scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.4),
              ),
              child: LoginScreen(authService: _testAuthService()),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Welcome back'), findsOneWidget);
        expect(find.text('Email address'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.text('Sign in'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // Issue #232's core acceptance criteria, exercised end-to-end through the
  // main app's *existing* sign-in screen (no second merchant sign-in UI):
  // after a successful sign-in, a `merchant`/`admin` `profiles.role` lands on
  // the merchant dashboard route instead of the customer home, and a
  // `customer` role's sign-in is unaffected.
  group('merchant redirect after sign-in (issue #232)', () {
    http.Response sessionResponse(String userId) {
      final now = DateTime.now().toIso8601String();
      return http.Response(
        jsonEncode({
          'access_token': 'mock-access-token',
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': 'mock-refresh-token',
          'user': {
            'id': userId,
            'aud': 'authenticated',
            'email': 'user@example.com',
            'app_metadata': <String, dynamic>{},
            'user_metadata': <String, dynamic>{},
            'created_at': now,
          },
        }),
        200,
      );
    }

    /// Builds a [SupabaseClient] whose mocked HTTP transport answers both a
    /// password sign-in and the `profiles.role` lookup `MerchantRoleService`
    /// performs right after, so the same client can back both [AuthService]
    /// and [MerchantRoleService] in these tests exactly as production code
    /// shares one `Supabase.instance.client`.
    SupabaseClient clientWithRole(String userId, String role) {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          return sessionResponse(userId);
        }
        if (request.url.path == '/rest/v1/profiles') {
          // `postgrest`'s response parsing reads `response.request`, which
          // `MockClient` only forwards if the mocked `Response` sets it
          // explicitly (see `package:http/src/mock_client.dart`).
          return http.Response(
            jsonEncode({'role': role}),
            200,
            request: request,
          );
        }
        return http.Response('not found', 404);
      });
      return SupabaseClient(
        'https://example.supabase.co',
        'test-publishable-key',
        authOptions: _testAuthOptions,
        httpClient: mockClient,
      );
    }

    Future<void> pumpLoginAndSignIn(
      WidgetTester tester, {
      required SupabaseClient client,
    }) async {
      final router = GoRouter(
        initialLocation: AppRoutes.login,
        routes: [
          GoRoute(
            path: AppRoutes.login,
            builder: (_, _) => LoginScreen(
              authService: AuthService(client: client),
              merchantRoleService: MerchantRoleService(client: client),
            ),
          ),
          GoRoute(
            path: AppRoutes.mainApp,
            builder: (_, _) => const Scaffold(body: Text('customer home')),
          ),
          GoRoute(
            path: AppRoutes.merchantDashboard,
            builder: (_, _) => const Scaffold(body: Text('merchant dashboard')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      );
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, 'Email address').first,
        'user@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password').first,
        'password123',
      );
      // The sign-in card overflows the default test viewport, so the button
      // needs to be scrolled into view before it can be hit-tested.
      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
    }

    setUp(() {
      // Each test starts from a clean cached routing decision, mirroring a
      // fresh app launch (see `MerchantSessionGate`'s doc comment).
      MerchantSessionGate.reset();
    });

    testWidgets(
      'a merchant-role account lands on the merchant dashboard, not the '
      'customer home',
      (tester) async {
        final client = clientWithRole('merchant-1', 'merchant');

        await pumpLoginAndSignIn(tester, client: client);

        expect(find.text('merchant dashboard'), findsOneWidget);
        expect(find.text('customer home'), findsNothing);
        expect(MerchantSessionGate.isMerchantRole, isTrue);
      },
    );

    testWidgets('an admin-role account also lands on the merchant dashboard', (
      tester,
    ) async {
      final client = clientWithRole('admin-1', 'admin');

      await pumpLoginAndSignIn(tester, client: client);

      expect(find.text('merchant dashboard'), findsOneWidget);
    });

    testWidgets(
      "a customer-role account's sign-in is unchanged: it lands on the "
      'customer home',
      (tester) async {
        final client = clientWithRole('customer-1', 'customer');

        await pumpLoginAndSignIn(tester, client: client);

        expect(find.text('customer home'), findsOneWidget);
        expect(find.text('merchant dashboard'), findsNothing);
        expect(MerchantSessionGate.isMerchantRole, isFalse);
      },
    );
  });
}

// PKCE is the client's default auth flow, and it requires an async-storage
// implementation to persist the code verifier. Production code gets one for
// free from `Supabase.initialize`; this test doesn't run through that, so
// the injected client opts into the implicit flow instead (skips storage
// entirely) and disables auto-refresh (skips a background timer that would
// otherwise still be pending when the widget tree is torn down) — same
// approach as `test/auth_service_test.dart`.
const _testAuthOptions = AuthClientOptions(
  authFlowType: AuthFlowType.implicit,
  autoRefreshToken: false,
);

AuthService _testAuthService() => AuthService(
  client: SupabaseClient(
    'https://example.supabase.co',
    'test-publishable-key',
    authOptions: _testAuthOptions,
  ),
);
