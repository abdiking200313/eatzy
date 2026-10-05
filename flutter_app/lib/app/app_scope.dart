import 'package:flutter/widgets.dart';

import 'app_services.dart';

/// Exposes the app's single [AppServices] instance to the widget tree.
///
/// Installed once near the root (see `main.dart`), wrapping [ZivoApp] so
/// every screen below it can reach shared dependencies via
/// `AppScope.of(context)` instead of a process-wide `.instance` singleton or
/// a default-parameter `Supabase.instance.client` fallback. See
/// `vault/Conventions.md` "Getting dependencies in a new screen" for the
/// expected pattern going forward.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  /// The [AppServices] from the nearest ancestor [AppScope]. Throws (via the
  /// assertion below) if there isn't one — every screen reachable from
  /// `ZivoApp` is expected to be a descendant of the [AppScope] installed in
  /// `main.dart`.
  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in context');
    return scope!.services;
  }

  /// As [of], but returns null instead of asserting when there is no
  /// ancestor [AppScope] — for the rare call site that can legitimately run
  /// without one (e.g. a standalone widget test not under test).
  static AppServices? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()?.services;

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
