import 'dart:async';

import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/home/models/category.dart';
import 'package:chowflow/features/home/models/restaurant.dart';
import 'package:chowflow/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('food home coordinates category and restaurant loading', (
    tester,
  ) async {
    final categories = Completer<List<Category>>();
    final restaurants = Completer<List<Restaurant>>();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: HomeScreen(
          categoryLoader: () => categories.future,
          restaurantLoader: () => restaurants.future,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    categories.complete(const [
      Category(id: 'rice', name: 'Rice', iconUrl: ''),
    ]);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Rice'), findsNothing);

    restaurants.complete(const [
      Restaurant(
        id: 'restaurant-1',
        name: 'Mogadishu Kitchen',
        description: 'Somali favourites',
        logoUrl: '',
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Mogadishu Kitchen'), findsOneWidget);
    expect(find.text('Today’s deals'), findsNothing);
  });

  testWidgets('food home stays overflow-free on a narrow, large-text screen', (
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
          child: ZivoServiceTheme(
            serviceId: ServiceId.food,
            child: HomeScreen(
              categoryLoader: () async => const [
                Category(id: 'rice', name: 'Rice', iconUrl: ''),
              ],
              restaurantLoader: () async => const [
                Restaurant(
                  id: 'restaurant-1',
                  name: 'Mogadishu Kitchen',
                  description: 'Somali favourites',
                  logoUrl: '',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mogadishu Kitchen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
