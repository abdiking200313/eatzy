import 'package:chowflow/features/home/models/restaurant.dart';
import 'package:chowflow/services/food/presentation/food_explore_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('food Explore lists restaurants rather than service modules', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FoodExploreScreen(
          restaurants: Future.value(const [
            Restaurant(
              id: 'restaurant-1',
              name: 'Mogadishu Kitchen',
              description: 'Somali favourites',
              logoUrl: '',
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Explore restaurants'), findsOneWidget);
    expect(find.text('Mogadishu Kitchen'), findsOneWidget);
    expect(find.text('Grocery'), findsNothing);
    expect(find.text('Pharmacy'), findsNothing);
  });
}
