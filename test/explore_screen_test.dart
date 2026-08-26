import 'package:chowflow/config/theme.dart';
import 'package:chowflow/screens/explore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('explore lists every service module as a white card', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const ExploreScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Explore'), findsOneWidget);
    for (final label in ['Food', 'Grocery', 'Pharmacy']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('explore stays overflow-free on a narrow, large-text screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.4),
          ),
          child: const ExploreScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Food'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
