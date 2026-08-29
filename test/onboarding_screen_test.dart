import 'package:chowflow/app/app_routes.dart';
import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/onboarding/presentation/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/network_image_mock.dart';

void main() {
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
    await withMockNetworkImages(() async {
      await tester.pumpWidget(
        MaterialApp.router(theme: buildAppTheme(), routerConfig: buildRouter()),
      );
      await tester.pump();

      expect(find.text('Discover Flavors'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });
  });

  testWidgets(
    'welcome screen stays overflow-free on a narrow, large-text screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await withMockNetworkImages(() async {
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

        expect(find.text('Discover Flavors'), findsOneWidget);
        expect(find.text('Get Started'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    },
  );
}
