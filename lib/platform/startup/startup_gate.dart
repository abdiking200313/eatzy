import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/merchant_session_gate.dart';
import '../../config/env.dart';
import '../../config/theme.dart';
import '../../features/onboarding/data/onboarding_preferences.dart';
import '../../features/settings/data/notification_preferences_repository.dart';
import '../../services/food/presentation/cart_controller.dart';
import '../../services/grocery/models/grocery_models.dart';
import '../../services/grocery/presentation/grocery_controller.dart';
import '../../services/pharmacy/presentation/pharmacy_controller.dart';
import '../../widgets/zivo_logo.dart';
import '../activity/data/activity_repository.dart';
import '../activity/presentation/activity_controller.dart';
import '../error_reporting/error_reporter.dart';
import '../notifications/push_notifications.dart';
import '../session/secure_session_storage.dart';

/// How long any single startup network call is allowed to run before it is
/// treated as failed (issue #41). Chosen to comfortably cover a slow mobile
/// connection while still giving up well before a user assumes the app is
/// permanently frozen.
const Duration kStartupNetworkTimeout = Duration(seconds: 15);

/// What [runStartupSequence] hands back on success: the already-configured
/// singleton controllers the real app root needs. Kept as a named result
/// (rather than returning the bare [CartController]) so a future caller can
/// add another controller without changing the function's return type.
class StartupResult {
  const StartupResult({required this.cartController});

  final CartController cartController;
}

/// Runs every startup step that used to block `main()` before `runApp`
/// (issue #41): `Supabase.initialize`, the onboarding-seen flag, the food /
/// grocery / pharmacy cart loads, and (for a signed-in user) the initial
/// activity load.
///
/// `Supabase.initialize` is the one call the rest of the app cannot function
/// without, so its failure (including timing out) is fatal and rethrown --
/// [StartupGate] turns that into a retry screen instead of a frozen splash.
/// Every other step degrades instead of blocking: it is individually timed
/// out and any error is reported via [ErrorReporting] and swallowed, so a
/// slow/broken cart or activity load does not stop the user from reaching
/// the app (they land with an empty cart / no recent activity instead,
/// which the relevant screens already know how to display and retry).
Future<StartupResult> runStartupSequence() async {
  const supabaseUrl = Env.supabaseUrl;
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureSessionStorage(supabaseUrl: supabaseUrl),
      ),
    ).timeout(kStartupNetworkTimeout);
  } on Object catch (error, stackTrace) {
    ErrorReporting.instance.reportError(
      error,
      stackTrace,
      context: 'Supabase.initialize',
    );
    rethrow;
  }

  // Loaded once, up front, so AppRouter's synchronous redirect can gate a
  // returning signed-out user past onboarding on this very first frame --
  // see OnboardingLaunchGate and issue #15. A failure here only means a
  // returning user might see onboarding again, so it falls back to `false`
  // (show onboarding) rather than blocking startup.
  await _runBestEffort('OnboardingLaunchGate.hasSeenOnboarding', () async {
    OnboardingLaunchGate.hasSeenOnboarding =
        await const SharedPreferencesOnboardingPreferences()
            .hasSeenOnboarding()
            .timeout(kStartupNetworkTimeout);
  }, onFailure: () => OnboardingLaunchGate.hasSeenOnboarding = false);

  final cartController = CartController.instance;
  final currentUserId = Supabase.instance.client.auth.currentUser?.id;

  // Issue #232: resolve merchant/admin routing once at startup for a
  // restored session, so AppRouter's synchronous redirect can send a
  // merchant/admin account to the merchant dashboard on this very first
  // frame instead of the customer home -- mirrors the OnboardingLaunchGate
  // load above. Best-effort: a failed lookup falls back to `false`
  // (customer routing), the same fail-closed behavior as
  // MerchantRoleService.fetchRole itself.
  if (currentUserId == null) {
    MerchantSessionGate.reset();
  } else {
    await _runBestEffort(
      'MerchantSessionGate.resolveFor',
      () => MerchantSessionGate.resolveFor(
        currentUserId,
      ).timeout(kStartupNetworkTimeout),
      onFailure: MerchantSessionGate.reset,
    );
  }

  // Firebase init + an initial permission prompt (issue #47), Android only
  // -- see PushNotificationGateway's doc comment. Best-effort like every
  // other step here: a user with push notifications off (or a device that
  // can't reach Firebase) still reaches the app normally, just without a
  // token. Respects the #10 preference already on disk for a returning
  // signed-in user instead of re-prompting regardless of their choice; a
  // signed-out user (or one who has never set a preference) falls back to
  // NotificationPreferences.defaults, which has push on.
  await _runBestEffort('PushNotifications.initialize', () async {
    await PushNotifications.instance.initialize().timeout(
      kStartupNetworkTimeout,
    );
    final preferences = currentUserId == null
        ? NotificationPreferences.defaults
        : await SharedPreferencesNotificationPreferencesStorage()
              .read(currentUserId)
              .timeout(kStartupNetworkTimeout);
    if (preferences.pushNotifications) {
      await PushNotifications.instance.requestPermission().timeout(
        kStartupNetworkTimeout,
      );
    }
  });

  await _runBestEffort(
    'CartController.loadForOwner',
    () => cartController
        .loadForOwner(currentUserId)
        .timeout(kStartupNetworkTimeout),
  );
  // Grocery, Fresh Meat and Electronics each keep their own cart.
  for (final type in GroceryStoreType.values) {
    await _runBestEffort(
      'GroceryController(${type.dbValue}).loadForOwner',
      () => GroceryController.forType(
        type,
      ).loadForOwner(currentUserId).timeout(kStartupNetworkTimeout),
    );
  }
  await _runBestEffort(
    'PharmacyController.loadForOwner',
    () => PharmacyController.instance
        .loadForOwner(currentUserId)
        .timeout(kStartupNetworkTimeout),
  );

  ActivityController.instance.configureRepository(
    SupabaseActivityRepository(client: Supabase.instance.client),
  );
  if (currentUserId != null) {
    await _runBestEffort(
      'ActivityController.load',
      () => ActivityController.instance.load().timeout(kStartupNetworkTimeout),
    );
  }

  return StartupResult(cartController: cartController);
}

/// Runs [body], reporting and swallowing any failure (including a timeout)
/// instead of letting it abort the rest of [runStartupSequence]. [onFailure]
/// runs synchronously after a failure is reported, for callers that need to
/// apply a fallback value.
Future<void> _runBestEffort(
  String context,
  Future<void> Function() body, {
  void Function()? onFailure,
}) async {
  try {
    await body();
  } on Object catch (error, stackTrace) {
    ErrorReporting.instance.reportError(error, stackTrace, context: context);
    onFailure?.call();
  }
}

/// Root widget installed by `runApp` in place of the real app (issue #41):
/// runs [runStartup] once mounted and shows a loading state while it's in
/// flight, an error/retry state if it fails, or hands off to [onReady] with
/// the loaded [CartController] once it succeeds -- so a slow or failed
/// network call blocks a lightweight bootstrap screen instead of `runApp`
/// itself, and a failure is always recoverable instead of leaving a
/// permanently black/frozen screen.
class StartupGate extends StatefulWidget {
  const StartupGate({
    super.key,
    required this.onReady,
    this.runStartup = runStartupSequence,
  });

  /// Builds the real app once startup succeeds.
  final Widget Function(CartController cartController) onReady;

  /// Overridable for tests; defaults to [runStartupSequence].
  final Future<StartupResult> Function() runStartup;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

enum _StartupStatus { loading, failed }

class _StartupGateState extends State<StartupGate> {
  _StartupStatus _status = _StartupStatus.loading;
  StartupResult? _result;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    setState(() {
      _status = _StartupStatus.loading;
      _result = null;
    });
    try {
      final result = await widget.runStartup();
      if (!mounted) return;
      setState(() => _result = result);
    } on Object catch (error, stackTrace) {
      ErrorReporting.instance.reportError(
        error,
        stackTrace,
        context: 'StartupGate',
      );
      if (!mounted) return;
      setState(() => _status = _StartupStatus.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result != null) {
      return widget.onReady(result.cartController);
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: _status == _StartupStatus.failed
          ? _StartupErrorView(onRetry: _start)
          : const _StartupLoadingView(),
    );
  }
}

class _StartupLoadingView extends StatelessWidget {
  const _StartupLoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ZivoLogo(),
            const SizedBox(height: TwSpacing.x8),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _StartupErrorView extends StatelessWidget {
  const _StartupErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwColors.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(TwSpacing.x8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: TwColors.textMuted,
                size: 40,
              ),
              const SizedBox(height: TwSpacing.x4),
              Text(
                "Couldn't connect",
                textAlign: TextAlign.center,
                style: TwText.fontBoldBase,
              ),
              const SizedBox(height: TwSpacing.x2),
              Text(
                'Check your internet connection and try again.',
                textAlign: TextAlign.center,
                style: TwText.textSm.copyWith(color: TwColors.textMuted),
              ),
              const SizedBox(height: TwSpacing.x6),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}
