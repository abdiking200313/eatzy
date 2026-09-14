import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_router.dart';
import 'config/theme.dart';
import 'features/onboarding/data/onboarding_preferences.dart';
import 'platform/activity/data/activity_repository.dart';
import 'platform/activity/presentation/activity_controller.dart';
import 'platform/error_reporting/error_reporter.dart';
import 'platform/session/account_state_coordinator.dart';
import 'platform/session/secure_session_storage.dart';
import 'platform/system_ui/android_navigation_bar_controller.dart';
import 'services/food/presentation/cart_controller.dart';
import 'services/grocery/presentation/grocery_controller.dart';
import 'services/pharmacy/presentation/pharmacy_controller.dart';
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

      const supabaseUrl = 'https://jzubookmbrtslocuzepe.supabase.co';
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: 'sb_publishable_yLgLRnh00I5zjImD-Q7R6A_uOO-l0sT',
        authOptions: FlutterAuthClientOptions(
          localStorage: SecureSessionStorage(supabaseUrl: supabaseUrl),
        ),
      );

      // Loaded once, up front, so AppRouter's synchronous redirect can gate
      // a returning signed-out user past onboarding on this very first
      // frame -- see OnboardingLaunchGate and issue #15.
      OnboardingLaunchGate.hasSeenOnboarding =
          await const SharedPreferencesOnboardingPreferences()
              .hasSeenOnboarding();

      final cartController = CartController.instance;
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      await cartController.loadForOwner(currentUserId);
      await GroceryController.instance.loadForOwner(currentUserId);
      await PharmacyController.instance.loadForOwner(currentUserId);
      ActivityController.instance.configureRepository(
        SupabaseActivityRepository(client: Supabase.instance.client),
      );
      if (currentUserId != null) {
        await ActivityController.instance.load();
      }

      runApp(ZivoApp(cartController: cartController));
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
