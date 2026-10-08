import 'package:cached_network_image/cached_network_image.dart';
import 'package:chowflow/config/theme.dart';
import 'package:chowflow/widgets/app_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester, {String? imageUrl}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: StoreListCard(
            name: 'Bakaara Mart',
            subtitle: 'Bakaara',
            imageUrl: imageUrl,
            accentColor: TwColors.primary,
            onTap: () {},
          ),
        ),
      ),
    );
    // Not pumpAndSettle: a real imageUrl would leave CachedNetworkImage's
    // network/retry timers running and hang pumpAndSettle -- a single pump
    // is enough to assert which branch (photo vs placeholder) was built.
    await tester.pump();
  }

  testWidgets(
    'shows the "No picture available" placeholder when imageUrl is null',
    (tester) async {
      await pumpCard(tester, imageUrl: null);

      expect(find.text('No picture available'), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    },
  );

  testWidgets(
    'shows the "No picture available" placeholder when imageUrl is empty',
    (tester) async {
      await pumpCard(tester, imageUrl: '');

      expect(find.text('No picture available'), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
    },
  );

  testWidgets('shows the photo, not the placeholder, when imageUrl is set', (
    tester,
  ) async {
    await pumpCard(tester, imageUrl: 'https://example.com/store.jpg');

    expect(find.text('No picture available'), findsNothing);
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('always renders the name and subtitle', (tester) async {
    await pumpCard(tester, imageUrl: null);

    expect(find.text('Bakaara Mart'), findsOneWidget);
    expect(find.text('Bakaara'), findsOneWidget);
  });
}
