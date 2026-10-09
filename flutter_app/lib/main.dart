import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_router.dart';
import 'app/app_scope.dart';
import 'app/app_services.dart';
import 'config/theme.dart';
import 'platform/error_reporting/error_reporter.dart';
import 'platform/session/account_state_coordinator.dart';
import 'platform/startup/startup_gate.dart';
import 'platform/system_ui/android_navigation_bar_controller.dart';
import 'services/food/presentation/cart_controller.dart';
import 'widgets/error_fallback.dart';
import 'widgets/zivo_logo.dart';

// Global error handling: every hook below reports through
// `ErrorReporting.instance`
// (`lib/platform/error_reporting/error_reporter.dart`), which
// `runStartupSequence` (`lib/platform/startup/startup_gate.dart`) points at
// a Firebase Crashlytics-backed implementation in release/profile builds --
// these handlers stay the same regardless of which `ErrorReporter`
// implementation that resolves to.
void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Replaces Flutter's default grey ErrorWidget box with an on-brand
      // fallback for any widget subtree that fails to build.
      ErrorWidget.builder = (_) => const ErrorFallbackView();

      // Framework-caught errors (e.g. a widget build failure) still get
      // Flutter's normal debug-console dump via presentError, in addition to
      // being routed through the shared reporter.
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        previousOnError?.call(details);
        ErrorReporting.instance.reportError(
          details.exception,
          details.stack ?? StackTrace.current,
          context: 'FlutterError',
        );
      };

      // Errors thrown outside the Flutter framework's own error zone (e.g.
      // from a platform channel callback).
      PlatformDispatcher.instance.onError = (error, stack) {
        ErrorReporting.instance.reportError(
          error,
          stack,
          context: 'PlatformDispatcher',
        );
        return true;
      };

      // Lock the app to portrait orientation. This is the single
      // cross-platform source of truth; ios/Runner/Info.plist and
      // android/app/src/main/AndroidManifest.xml are also restricted to
      // portrait for defense-in-depth.
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // `runApp` starts immediately with `StartupGate`, which runs
      // `Supabase.initialize`, the onboarding flag, and the cart/activity
      // loads itself (see `platform/startup/startup_gate.dart`) behind a
      // loading state, each step individually timed out, showing a retry
      // screen instead of a permanently black/frozen one if a step fails
      // or hangs (e.g. a slow or captive-portal connection).
      runApp(
        StartupGate(
          onReady: (appServices) => AppScope(
            services: appServices,
            child: ZivoApp(appServices: appServices),
          ),
        ),
      );
    },
    (error, stack) {
      ErrorReporting.instance.reportError(
        error,
        stack,
        context: 'runZonedGuarded',
      );
    },
  );
}

class ZivoApp extends StatefulWidget {
  const ZivoApp({super.key, required this.appServices});

  /// The composition root this app instance runs on. Passed
  /// explicitly rather than read via `AppScope.of(context)` because
  /// [_ZivoAppState.initState] needs it before this widget's own context has
  /// an `AppScope` ancestor available to `dependOnInheritedWidgetOfExactType`
  /// -- callers are expected to also wrap this widget in an `AppScope` using
  /// the same instance (see `main.dart`), so descendants can look it up via
  /// context instead.
  final AppServices appServices;

  @override
  State<ZivoApp> createState() => _ZivoAppState();
}

class _ZivoAppState extends State<ZivoApp> {
  final AndroidNavigationBarController _navigationBarController =
      AndroidNavigationBarController();
  late final CartController _cartController = widget.appServices.cartController;
  late final AccountStateCoordinator _accountStateCoordinator =
      AccountStateCoordinator(
        initialOwnerId: _cartController.ownerId,
        activityController: widget.appServices.activityController,
        registry: widget.appServices.sessionResetRegistry,
      );
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _navigationBarController.start();
    _authSubscription = widget.appServices.supabaseClient.auth.onAuthStateChange
        .listen((authState) {
          final nextOwnerId = authState.session?.user.id;
          if (_accountStateCoordinator.handleOwnerChanged(nextOwnerId)) {
            unawaited(_cartController.loadForOwner(nextOwnerId));
            if (nextOwnerId != null) {
              unawaited(widget.appServices.activityController.load());
            }
          }
        });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _navigationBarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: ZivoBrand.name,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: AppRouter.router,
    );
  }
}
