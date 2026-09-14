import 'package:chowflow/app/app_routes.dart';
import 'package:chowflow/app/not_found_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('NotFoundScreen shows a message and a way back to a known route '
      '(issue #40)', (tester) async {
    final router = GoRouter(
      initialLocation: '/this-path-does-not-exist',
      routes: [
        GoRoute(
          path: AppRoutes.mainApp,
          builder: (_, _) => const Scaffold(body: Text('home screen')),
        ),
      ],
      errorBuilder: (_, _) => const NotFoundScreen(),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text("We couldn't find that page"), findsOneWidget);
    expect(find.text('Go to home'), findsOneWidget);
    expect(find.text('home screen'), findsNothing);

    await tester.tap(find.text('Go to home'));
    await tester.pumpAndSettle();

    expect(find.text('home screen'), findsOneWidget);
    expect(find.text("We couldn't find that page"), findsNothing);
  });
}
