import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_router.dart';
import 'config/theme.dart';
import 'platform/activity/presentation/activity_controller.dart';
import 'platform/error_reporting/error_reporter.dart';
import 'platform/session/account_state_coordinator.dart';
import 'platform/startup/startup_gate.dart';
import 'platform/system_ui/android_navigation_bar_controller.dart';
import 'services/food/presentation/cart_controller.dart';
import 'widgets/error_fallback.dart';
import 'widgets/zivo_logo.dart';

// Global error handling scaffolding (issue #40). There is no crash-reporting
// SDK wired in yet — Firebase Crashlytics is the owner's chosen SDK, deferred
// to a fast-follow once `google-services.json` / `GoogleService-Info.plist`
// exist for a real Firebase project (see the issue's follow-up decision) —
// so every hook below reports through `ErrorReporting.instance`
// (`lib/platform/error_reporting/error_reporter.dart`), which currently just
// logs. Swapping in Crashlytics later only means replacing that one
// instance, not touching these handlers.
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
      // portrait for defense-in-depth (see issue #56).
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // `Supabase.initialize`, the onboarding flag, and the cart/activity
      // loads all used to run here, blocking `runApp` on unbounded network
      // I/O with no timeout and no failure handling (issue #41): a slow or
      // captive-portal connection hung the native splash screen forever,
      // and a thrown `Supabase.initialize` meant `runApp` was never reached
      // at all. `runApp` now starts immediately with `StartupGate`, which
      // runs that same sequence itself (see
      // `platform/startup/startup_gate.dart`) behind a loading state, each
      // step individually timed out, and shows a retry screen instead of a
      // permanently black/frozen one if it fails.
      runApp(
        StartupGate(
          onReady: (cartController) => ZivoApp(cartController: cartController),
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
  const ZivoApp({super.key, this.cartController});

  final CartController? cartController;

  @override
  State<ZivoApp> createState() => _ZivoAppState();
}

class _ZivoAppState extends State<ZivoApp> {
  final AndroidNavigationBarController _navigationBarController =
      AndroidNavigationBarController();
  late final CartController _cartController =
      widget.cartController ?? CartController.instance;
  late final AccountStateCoordinator _accountStateCoordinator =
      AccountStateCoordinator(initialOwnerId: _cartController.ownerId);
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _navigationBarController.start();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      authState,
    ) {
      final nextOwnerId = authState.session?.user.id;
      if (_accountStateCoordinator.handleOwnerChanged(nextOwnerId)) {
        unawaited(_cartController.loadForOwner(nextOwnerId));
        if (nextOwnerId != null) {
          unawaited(ActivityController.instance.load());
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
