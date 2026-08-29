import 'dart:async';

import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/config/theme.dart';
import 'package:chowflow/services/food/models/category.dart';
import 'package:chowflow/services/food/models/restaurant.dart';
import 'package:chowflow/services/food/presentation/home_screen.dart';
import 'package:chowflow/services/food/presentation/widgets/category_card.dart';
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

  testWidgets('tapping a category chip runs a real, server-side filter', (
    tester,
  ) async {
    final queryCalls = <({String? searchQuery, String? categoryId})>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: HomeScreen(
          categoryLoader: () async => const [
            Category(id: 'rice', name: 'Rice', iconUrl: ''),
            Category(id: 'grill', name: 'Grill', iconUrl: ''),
          ],
          restaurantLoader: () async => const [
            Restaurant(
              id: 'restaurant-1',
              name: 'Mogadishu Kitchen',
              description: 'Somali favourites',
              logoUrl: '',
            ),
          ],
          restaurantQuery: ({searchQuery, categoryId}) async {
            queryCalls.add((searchQuery: searchQuery, categoryId: categoryId));
            if (categoryId == 'rice') {
              return const [
                Restaurant(
                  id: 'restaurant-2',
                  name: 'Rice Bowl',
                  description: 'Rice specialists',
                  logoUrl: '',
                ),
              ];
            }
            return const [];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Before selecting a category, the unfiltered list is shown as-is.
    expect(find.text('Mogadishu Kitchen'), findsOneWidget);
    expect(queryCalls, isEmpty);

    await tester.tap(find.widgetWithText(CategoryCard, 'Rice'));
    await tester.pumpAndSettle();

    expect(queryCalls, [(searchQuery: null, categoryId: 'rice')]);
    expect(find.text('Rice Bowl'), findsOneWidget);
    expect(find.text('Mogadishu Kitchen'), findsNothing);

    // Tapping the same chip again clears the filter.
    await tester.tap(find.widgetWithText(CategoryCard, 'Rice'));
    await tester.pumpAndSettle();

    expect(find.text('Mogadishu Kitchen'), findsOneWidget);
    expect(find.text('Rice Bowl'), findsNothing);
  });

  testWidgets('typing a search term debounces before filtering', (
    tester,
  ) async {
    final queryCalls = <String?>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: HomeScreen(
          categoryLoader: () async => const [],
          restaurantLoader: () async => const [
            Restaurant(
              id: 'restaurant-1',
              name: 'Mogadishu Kitchen',
              description: 'Somali favourites',
              logoUrl: '',
            ),
          ],
          restaurantQuery: ({searchQuery, categoryId}) async {
            queryCalls.add(searchQuery);
            return const [
              Restaurant(
                id: 'restaurant-3',
                name: 'Kitchen Express',
                description: 'Fast Somali food',
                logoUrl: '',
              ),
            ];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'kitchen');
    // Still within the debounce window — no query fired yet.
    await tester.pump(const Duration(milliseconds: 100));
    expect(queryCalls, isEmpty);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(queryCalls, ['kitchen']);
    expect(find.text('Kitchen Express'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    expect(find.text('Mogadishu Kitchen'), findsOneWidget);
    expect(find.text('Kitchen Express'), findsNothing);
  });

  testWidgets(
    'an empty filtered result set shows a reachable, honest empty state',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: HomeScreen(
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
            restaurantQuery: ({searchQuery, categoryId}) async => const [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(CategoryCard, 'Rice'));
      await tester.pumpAndSettle();

      expect(
        find.text('No restaurants found in this category.'),
        findsOneWidget,
      );
    },
  );
}
