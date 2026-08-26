import 'package:flutter/foundation.dart';

/// Invoked when the authenticated account changes, so a service module can
/// clear its own account-scoped in-memory state (cart contents, pending
/// confirmations, and similar). Registered by the service module itself.
typedef SessionResetCallback = void Function();

/// Lets service modules (grocery, pharmacy, ...) participate in
/// account-change session resets without the shared platform layer
/// importing service-specific controllers.
///
/// See `AGENTS.md` "Super-app architecture": shared/platform code must not
/// depend on service-module concepts. [AccountStateCoordinator] lives under
/// `lib/platform/session/` and previously constructed and imported
/// `GroceryController`/`PharmacyController` directly to reset their state on
/// sign-out; that inversion is fixed by having each service module register
/// a reset callback here instead, typically from its controller's lazy
/// singleton initializer.
class SessionResetRegistry {
  SessionResetRegistry();

  /// The registry app-wide singletons register into and that
  /// [AccountStateCoordinator] listens to by default.
  static final SessionResetRegistry instance = SessionResetRegistry();

  final List<SessionResetCallback> _callbacks = [];

  /// Registers [callback] to run on every account change. Returns a
  /// function that removes the registration again; mainly useful for tests,
  /// since app-wide controller singletons live for the app's lifetime.
  VoidCallback register(SessionResetCallback callback) {
    _callbacks.add(callback);
    return () => _callbacks.remove(callback);
  }

  /// Runs every registered callback. Callbacks are copied first so a
  /// callback that registers or removes another during the call can't
  /// disturb this pass.
  void notifyAll() {
    for (final callback in List<SessionResetCallback>.of(_callbacks)) {
      callback();
    }
  }

  @visibleForTesting
  void clearForTest() => _callbacks.clear();
}
