import 'package:chowflow/app/app_services.dart';
import 'package:chowflow/main.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/platform/cache/query_cache.dart';
import 'package:chowflow/platform/error_reporting/error_reporter.dart';
import 'package:chowflow/platform/session/session_reset_registry.dart';
import 'package:chowflow/services/food/models/cart_item.dart';
import 'package:chowflow/services/food/presentation/cart_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/app_scope_test_helpers.dart';
import 'helpers/memory_cart_storage.dart';

// PKCE needs async storage for its code verifier; the implicit flow skips
// that, matching `auth_service_test.dart`/`login_screen_test.dart`'s
// convention for a Supabase client under test.
final _testAuthOptions = FlutterAuthClientOptions(
  authFlowType: AuthFlowType.implicit,
  localStorage: const EmptyLocalStorage(),
  pkceAsyncStorage: MemoryGotrueAsyncStorage(),
);

void main() {
  // `Supabase.initialize` may only run once per isolate; `flutter test` runs
  // each test file in its own isolate, so this is safe here without
  // clobbering any other test file's Supabase singleton.
  setUpAll(() async {
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-publishable-key',
      httpClient: MockClient((request) async => http.Response('{}', 200)),
      authOptions: _testAuthOptions,
    );
  });

  testWidgets(
    'ZivoApp reads its cart/activity controllers from the AppServices it is '
    'given, not from the process-wide singletons (issue #281)',
    (tester) async {
      final cartController = CartController(
        storage: MemoryCartStorage<CartItem>(),
      );
      final activityController = ActivityController();
      final appServices = buildTestAppServices(
        supabaseClient: Supabase.instance.client,
        cartController: cartController,
        activityController: activityController,
      );

      await tester.pumpWidget(ZivoApp(appServices: appServices));
      await tester.pump();

      // Reaching the welcome screen (the signed-out initial route) without
      // throwing demonstrates the whole wiring -- AppRouter's redirect reads
      // the real `Supabase.instance.client`, so this also exercises the
      // `_authSubscription` set up in `initState` against the *injected*
      // `appServices.supabaseClient` rather than a second, divergent client.
      expect(find.text('Get Started'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('AppServices.fromSingletons wires every field to the matching '
      'process-wide .instance (phase 1 keeps them identical, issue #281)', () {
    // Supabase was initialized in setUpAll above, so Supabase.instance is
    // safe to read here too.
    expect(
      AppServices.fromSingletons().cartController,
      same(CartController.instance),
    );
    expect(
      AppServices.fromSingletons().activityController,
      same(ActivityController.instance),
    );
    expect(AppServices.fromSingletons().queryCache, same(QueryCache.instance));
    expect(
      AppServices.fromSingletons().sessionResetRegistry,
      same(SessionResetRegistry.instance),
    );
    expect(
      AppServices.fromSingletons().errorReporter,
      same(ErrorReporting.instance),
    );
  });
}
