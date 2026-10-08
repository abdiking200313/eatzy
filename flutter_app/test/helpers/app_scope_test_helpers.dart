import 'package:chowflow/app/app_scope.dart';
import 'package:chowflow/app/app_services.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/platform/cache/query_cache.dart';
import 'package:chowflow/platform/error_reporting/error_reporter.dart';
import 'package:chowflow/platform/session/session_reset_registry.dart';
import 'package:chowflow/services/food/models/cart_item.dart';
import 'package:chowflow/services/food/presentation/cart_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'memory_cart_storage.dart';

/// An in-memory [QueryCacheStorage], mirroring [MemoryCartStorage] -- used so
/// a test [AppServices]' [QueryCache] never touches a real SharedPreferences
/// platform channel.
class MemoryQueryCacheStorage implements QueryCacheStorage {
  final Map<String, String> values = {};

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);

  @override
  Future<void> write(String key, String json) async => values[key] = json;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

/// A [SupabaseClient] pointed at a fake project URL, suitable for an
/// [AppServices] test double that never expects a real network call. Uses
/// the implicit auth flow (like `auth_service_test.dart`/`login_screen_test
/// .dart`) so it needs no async-storage/platform-channel setup for PKCE, and
/// disables the auto-refresh timer -- otherwise `testWidgets` fails with "A
/// Timer is still pending even after the widget tree was disposed" since
/// nothing in a widget test ever calls `SupabaseClient.dispose`.
SupabaseClient buildTestSupabaseClient() => SupabaseClient(
  'https://example.supabase.co',
  'test-publishable-key',
  authOptions: const AuthClientOptions(
    authFlowType: AuthFlowType.implicit,
    autoRefreshToken: false,
  ),
);

/// An in-memory [GotrueAsyncStorage], for a test `Supabase.initialize` call
/// that needs to avoid the real `shared_preferences` plugin channel (which
/// `flutter_test` does not mock by default) -- pass as `pkceAsyncStorage` on
/// [FlutterAuthClientOptions] alongside [AuthFlowType.implicit] (which skips
/// PKCE entirely but doesn't stop `Supabase.initialize` itself from
/// constructing a default `SharedPreferencesGotrueAsyncStorage` unless one
/// is supplied).
class MemoryGotrueAsyncStorage extends GotrueAsyncStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> getItem({required String key}) async => _values[key];

  @override
  Future<void> setItem({required String key, required String value}) async =>
      _values[key] = value;

  @override
  Future<void> removeItem({required String key}) async => _values.remove(key);
}

/// Builds a fully test-double [AppServices] for widget/unit tests that need
/// one -- an in-memory [CartController]/[ActivityController], a fresh
/// [QueryCache]/[SessionResetRegistry] backed by memory only, a
/// [LoggingErrorReporter], and a [SupabaseClient] that makes no real network
/// calls. Pass any field to override just that one default, e.g. to share a
/// single [CartController] between the services under test and separate
/// assertions.
AppServices buildTestAppServices({
  SupabaseClient? supabaseClient,
  QueryCache? queryCache,
  ErrorReporter? errorReporter,
  SessionResetRegistry? sessionResetRegistry,
  CartController? cartController,
  ActivityController? activityController,
}) {
  return AppServices(
    supabaseClient: supabaseClient ?? buildTestSupabaseClient(),
    queryCache: queryCache ?? QueryCache(storage: MemoryQueryCacheStorage()),
    errorReporter: errorReporter ?? const LoggingErrorReporter(),
    sessionResetRegistry: sessionResetRegistry ?? SessionResetRegistry(),
    cartController:
        cartController ??
        CartController(storage: MemoryCartStorage<CartItem>()),
    activityController: activityController ?? ActivityController(),
  );
}

/// Pumps [child] wrapped in an [AppScope] backed by [services] (or a fresh
/// [buildTestAppServices] result when omitted), inside a [MaterialApp] so
/// widgets that expect one ancestor (theming, routing, etc.) still work --
/// the common case for a widget test that just needs `AppScope.of(context)`
/// to resolve. Returns the [AppServices] actually used, so the caller can
/// assert against it even when it wasn't supplied explicitly.
Future<AppServices> pumpWithAppScope(
  WidgetTester tester,
  Widget child, {
  AppServices? services,
}) async {
  final resolvedServices = services ?? buildTestAppServices();
  await tester.pumpWidget(
    MaterialApp(
      home: AppScope(services: resolvedServices, child: child),
    ),
  );
  return resolvedServices;
}
