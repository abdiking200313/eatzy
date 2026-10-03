import 'dart:async';

import 'package:chowflow/platform/startup/startup_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_scope_test_helpers.dart';

void main() {
  testWidgets('shows a loading indicator while startup is in flight', (
    tester,
  ) async {
    final startupCompleter = Completer<StartupResult>();

    await tester.pumpWidget(
      StartupGate(
        runStartup: () => startupCompleter.future,
        onReady: (appServices) => const MaterialApp(home: Text('app ready')),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('app ready'), findsNothing);

    // Avoid leaving a pending timer/future dangling past the test.
    startupCompleter.complete(
      StartupResult(appServices: buildTestAppServices()),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('hands off to onReady once startup succeeds', (tester) async {
    final appServices = buildTestAppServices();

    await tester.pumpWidget(
      StartupGate(
        runStartup: () async => StartupResult(appServices: appServices),
        onReady: (services) => MaterialApp(
          home: Text('ready:${identical(services, appServices)}'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ready:true'), findsOneWidget);
  });

  testWidgets(
    'shows a retry screen instead of crashing when startup throws, and '
    'retrying can still succeed',
    (tester) async {
      var attempt = 0;
      final appServices = buildTestAppServices();

      await tester.pumpWidget(
        StartupGate(
          runStartup: () async {
            attempt++;
            if (attempt == 1) {
              throw const SocketException('no network');
            }
            return StartupResult(appServices: appServices);
          },
          onReady: (services) => const MaterialApp(home: Text('app ready')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Couldn't connect"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('app ready'), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(attempt, 2);
      expect(find.text('app ready'), findsOneWidget);
      expect(find.text("Couldn't connect"), findsNothing);
    },
  );
}

/// Minimal stand-in for `dart:io`'s `SocketException` so this test doesn't
/// need a real socket failure to exercise the error path -- any thrown
/// [Object] takes the same code path in [StartupGate].
class SocketException implements Exception {
  const SocketException(this.message);

  final String message;

  @override
  String toString() => 'SocketException: $message';
}
