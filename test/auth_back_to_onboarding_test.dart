import 'dart:async';

import 'package:chowflow/app/app_router.dart';
import 'package:chowflow/app/app_routes.dart';
import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/auth/presentation/login_screen.dart';
import 'package:chowflow/features/auth/presentation/register_screen.dart';
import 'package:chowflow/features/onboarding/data/onboarding_preferences.dart';
import 'package:chowflow/features/onboarding/presentation/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The back arrow on login/register goes back to the onboarding slides, even
/// for a returning user whose app opened straight on login (where the router
/// would otherwise redirect welcome -> login, issue #15).
void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    OnboardingLaunchGate.hasSeenOnboarding = true;
  });
  tearDown(() => OnboardingLaunchGate.hasSeenOnboarding = false);

  // Same redirect wiring as AppRouter._redirect, minus Supabase.
  GoRouter buildRouter(String initialLocation) => GoRouter(
    initialLocation: initialLocation,
    redirect: (_, state) => AppRouter.redirectFor(
      userId: null,
      location: state.uri.path,
      revisitWelcome: AppRouter.isWelcomeRevisit(state.uri),
    ),
    routes: [
      GoRoute(
        path: AppRoutes.welcome,
        builder: (_, _) => const WelcomeScreen(),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, _) => const RegisterScreen(),
      ),
    ],
  );

  Future<void> pumpRouter(WidgetTester tester, GoRouter router) async {
    // Tests render text in the wide "Ahem" font, so use a wide surface.
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a returning user is still sent from welcome to login', (
    tester,
  ) async {
    await pumpRouter(tester, buildRouter(AppRoutes.welcome));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text("See What's Open Near You"), findsNothing);
  });

  testWidgets('back on login with nothing behind it opens the onboarding', (
    tester,
  ) async {
    await pumpRouter(tester, buildRouter(AppRoutes.login));
    expect(find.text('Welcome back'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text("See What's Open Near You"), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
  });

  testWidgets('back on register with nothing behind it opens the onboarding', (
    tester,
  ) async {
    await pumpRouter(tester, buildRouter(AppRoutes.register));
    expect(find.text('Create your account'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text("See What's Open Near You"), findsOneWidget);
  });

  testWidgets('from the reopened onboarding, Log In still works and back '
      'returns to it', (tester) async {
    await pumpRouter(tester, buildRouter(AppRoutes.login));
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);

    // Login now sits on top of the onboarding, so back just pops to it.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text("See What's Open Near You"), findsOneWidget);
  });

  testWidgets('back still pops normally when login was pushed on top of '
      'another screen', (tester) async {
    final router = buildRouter(AppRoutes.welcomeRevisit);
    await pumpRouter(tester, router);
    expect(find.text("See What's Open Near You"), findsOneWidget);

    unawaited(router.push(AppRoutes.register));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text("See What's Open Near You"), findsOneWidget);
  });
}
