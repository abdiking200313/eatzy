import 'package:supabase_flutter/supabase_flutter.dart';

import '../platform/activity/presentation/activity_controller.dart';
import '../platform/cache/query_cache.dart';
import '../platform/error_reporting/error_reporter.dart';
import '../platform/session/session_reset_registry.dart';
import '../services/food/presentation/cart_controller.dart';

/// The app's composition root (issue #281, phase 1 of #280): a single plain
/// Dart object holding every shared dependency a screen/controller needs,
/// instead of each call site reaching for `Supabase.instance.client` or a
/// process-wide `.instance` singleton directly.
///
/// This is deliberately *not* a new state-management framework (no
/// Riverpod/get_it/provider) — see `AGENTS.md`'s "do not introduce a new
/// state management framework" rule. It's a plain constructor-injected
/// bundle, exposed to the widget tree via [AppScope] (`app_scope.dart`).
///
/// Phase 1 only wires up the dependencies already identified in #280's
/// audit as process-wide singletons that are safe to centralize without
/// touching any vertical's screens/controllers: the Supabase client,
/// [QueryCache], [ErrorReporter], [SessionResetRegistry], [CartController],
/// and [ActivityController]. `QueryCache.instance`,
/// `ErrorReporting.instance`, `SessionResetRegistry.instance`,
/// `CartController.instance`, and `ActivityController.instance` keep
/// working exactly as before for every call site that hasn't migrated yet —
/// phases #282-285 migrate individual verticals to read these off
/// [AppScope] instead. `PharmacyController`/`GroceryController` are
/// intentionally out of scope here; they belong to later phases.
class AppServices {
  AppServices({
    required this.supabaseClient,
    required this.queryCache,
    required this.errorReporter,
    required this.sessionResetRegistry,
    required this.cartController,
    required this.activityController,
  });

  /// Builds the production [AppServices], wired to the existing process-wide
  /// singletons. Called exactly once, from `runStartupSequence` after
  /// `Supabase.initialize` has completed successfully — every field read
  /// here must already be safe to use at that point.
  factory AppServices.fromSingletons() => AppServices(
    supabaseClient: Supabase.instance.client,
    queryCache: QueryCache.instance,
    errorReporter: ErrorReporting.instance,
    sessionResetRegistry: SessionResetRegistry.instance,
    cartController: CartController.instance,
    activityController: ActivityController.instance,
  );

  final SupabaseClient supabaseClient;
  final QueryCache queryCache;
  final ErrorReporter errorReporter;
  final SessionResetRegistry sessionResetRegistry;
  final CartController cartController;
  final ActivityController activityController;
}
