import 'package:chowflow/app/app_scope.dart';
import 'package:chowflow/app/app_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_scope_test_helpers.dart';

void main() {
  testWidgets(
    'AppScope.of resolves the AppServices from the nearest ancestor',
    (tester) async {
      AppServices? resolved;
      final services = buildTestAppServices();

      await tester.pumpWidget(
        MaterialApp(
          home: AppScope(
            services: services,
            child: Builder(
              builder: (context) {
                resolved = AppScope.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(resolved, same(services));
    },
  );

  testWidgets('AppScope.maybeOf returns null with no ancestor AppScope', (
    tester,
  ) async {
    AppServices? resolved;
    var called = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            called = true;
            resolved = AppScope.maybeOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(called, isTrue);
    expect(resolved, isNull);
  });

  testWidgets(
    'updateShouldNotify is true only when the AppServices instance changes',
    (tester) async {
      final first = buildTestAppServices();
      final second = buildTestAppServices();

      final sameInstance = AppScope(
        services: first,
        child: const SizedBox.shrink(),
      );
      final differentInstance = AppScope(
        services: second,
        child: const SizedBox.shrink(),
      );
      final rebuiltSameInstance = AppScope(
        services: first,
        child: const SizedBox.shrink(),
      );

      expect(differentInstance.updateShouldNotify(sameInstance), isTrue);
      expect(rebuiltSameInstance.updateShouldNotify(sameInstance), isFalse);
    },
  );

  testWidgets(
    'pumpWithAppScope returns the AppServices actually used by the pumped tree',
    (tester) async {
      AppServices? resolved;

      final used = await pumpWithAppScope(
        tester,
        Builder(
          builder: (context) {
            resolved = AppScope.of(context);
            return const SizedBox.shrink();
          },
        ),
      );

      expect(resolved, same(used));
    },
  );
}
