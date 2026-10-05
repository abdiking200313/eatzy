import 'dart:async';

import '../activity/presentation/activity_controller.dart';
import '../error_reporting/crashlytics_error_reporter.dart';
import '../error_reporting/error_reporter.dart';
import 'session_reset_registry.dart';

/// Clears account-scoped in-memory MVP state when the authenticated owner
/// changes. Seeded catalogs remain loaded because they contain no user data.
///
/// This is a `lib/platform/` file, so it must not import service-specific
/// controllers (see `AGENTS.md` "Super-app architecture"). Service modules
/// such as grocery and pharmacy instead register a reset callback with
/// [SessionResetRegistry], typically from their controller's lazy singleton
/// initializer; [ActivityController] is imported directly because activity
/// history is shared platform state, not a service-module concept. The
/// grocery and pharmacy carts are persisted per-owner (like the food cart),
/// so their registered callbacks reload the incoming owner's saved cart
/// rather than merely clearing it.
///
/// Also sets the Crashlytics user identifier to the new owner id (issue
/// #287), or clears it on sign-out -- a no-op in debug builds, where
/// [ErrorReporting.instance] is still [LoggingErrorReporter] rather than
/// [CrashlyticsErrorReporter].
class AccountStateCoordinator {
  AccountStateCoordinator({
    required String? initialOwnerId,
    ActivityController? activityController,
    SessionResetRegistry? registry,
  }) : _ownerId = initialOwnerId,
       _activityController = activityController ?? ActivityController.instance,
       _registry = registry ?? SessionResetRegistry.instance;

  String? _ownerId;
  final ActivityController _activityController;
  final SessionResetRegistry _registry;

  String? get ownerId => _ownerId;

  bool handleOwnerChanged(String? nextOwnerId) {
    if (_ownerId == nextOwnerId) {
      return false;
    }

    _ownerId = nextOwnerId;
    _activityController.resetSessionState();
    _registry.notifyAll(nextOwnerId);
    _updateCrashlyticsUserIdentifier(nextOwnerId);
    return true;
  }

  void _updateCrashlyticsUserIdentifier(String? ownerId) {
    final reporter = ErrorReporting.instance;
    if (reporter is CrashlyticsErrorReporter) {
      unawaited(reporter.setUserIdentifier(ownerId));
    }
  }
}
