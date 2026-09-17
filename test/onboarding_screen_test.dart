import 'package:chowflow/app/app_routes.dart';
import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/onboarding/data/onboarding_preferences.dart';
import 'package:chowflow/features/onboarding/presentation/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    OnboardingLaunchGate.hasSeenOnboarding = false;
  });

  GoRouter buildRouter() => GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const WelcomeScreen()),
      for (final path in [
        AppRoutes.mainApp,
        AppRoutes.register,
        AppRoutes.login,
      ])
        GoRoute(
          path: path,
          builder: (_, state) => Scaffold(body: Text(state.uri.path)),
        ),
    ],
  );

  testWidgets('welcome screen shows the first onboarding slide', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp.router(theme: buildAppTheme(), routerConfig: buildRouter()),
    );
    await tester.pump();

    expect(find.text("See What's Open Near You"), findsOneWidget);
    expect(find.text('Ayam Penyet Ria'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets(
    'welcome screen stays overflow-free on a narrow, large-text screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp.router(
          theme: buildAppTheme(),
          routerConfig: buildRouter(),
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.4),
            ),
            child: child!,
          ),
        ),
      );
      await tester.pump();

      expect(find.text("See What's Open Near You"), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('second and third slides render their redesigned content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp.router(theme: buildAppTheme(), routerConfig: buildRouter()),
    );
    await tester.pump();

    final pageView = find.byType(PageView);

    await tester.fling(pageView, const Offset(-800, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Order In A Few Taps'), findsOneWidget);
    expect(find.text('Ayam Penyet Ria'), findsOneWidget);
    expect(find.text('Total incl. delivery'), findsOneWidget);

    await tester.fling(pageView, const Offset(-800, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Know Exactly When It Lands'), findsOneWidget);
    expect(find.text('On the way'), findsOneWidget);
    expect(find.text('Rider picked up'), findsOneWidget);
  });

  group('onboarding first-launch gating (issue #15)', () {
    testWidgets('tapping Skip marks onboarding seen and opens the app', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp.router(theme: buildAppTheme(), routerConfig: buildRouter()),
      );
      await tester.pump();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.mainApp), findsOneWidget);
      expect(OnboardingLaunchGate.hasSeenOnboarding, isTrue);
    });

    testWidgets('tapping Get Started marks onboarding seen too', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp.router(theme: buildAppTheme(), routerConfig: buildRouter()),
      );
      await tester.pump();

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.register), findsOneWidget);
      expect(OnboardingLaunchGate.hasSeenOnboarding, isTrue);
    });
  });
}
