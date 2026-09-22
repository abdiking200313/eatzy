import 'package:cached_network_image/cached_network_image.dart';
import 'package:chowflow/screens/categories.dart';
import 'package:chowflow/services/food/models/category.dart';
import 'package:chowflow/services/food/presentation/widgets/categories_section.dart';
import 'package:chowflow/services/food/presentation/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'service photo cards render a real photo when photoUrl is set, a drawn '
    'placeholder when it is not, and never crash either way',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: CategoriesScreen(showBackButton: false)),
      );
      // Not pumpAndSettle: a real photoUrl would leave CachedNetworkImage's
      // network/retry timers running and hang pumpAndSettle -- a single
      // pump is enough to assert which background branch was built.
      await tester.pump();

      // Food and Grocery both have a real `photoUrl` (see
      // ServiceRegistry.modules) -- their cards render the photo path.
      for (final key in ['services-food', 'services-grocery']) {
        expect(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(CachedNetworkImage),
          ),
          findsOneWidget,
        );
      }

      // The "Delivery" coming-soon category has no `photoUrl` -- its card
      // falls back to the locally drawn accent-gradient + icon-watermark
      // placeholder, not a photo. It's the 5th of 7 (now taller, 148px
      // photo-card-height) list items, so it isn't built until scrolled
      // into view.
      final deliveryCard = find.byKey(
        const Key('services-coming-soon-delivery'),
      );
      await tester.scrollUntilVisible(deliveryCard, 200);
      await tester.pump();
      expect(
        find.descendant(
          of: deliveryCard,
          matching: find.byType(CachedNetworkImage),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: deliveryCard,
          matching: find.byIcon(Icons.local_shipping_outlined),
        ),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('standalone category placeholder renders from one file', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: CategoriesScreen(showBackButton: false)),
    );

    expect(find.text('Services'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);

    for (final label in ['Food', 'Pharmacy', 'Grocery']) {
      await tester.scrollUntilVisible(
        find.text(label),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('services list includes coming-soon categories', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CategoriesScreen(showBackButton: false)),
    );

    final electronics = find.byKey(
      const Key('services-coming-soon-electronics'),
    );
    await tester.scrollUntilVisible(
      electronics,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Electronics'), findsOneWidget);

    await tester.tap(electronics);
    await tester.pump();
    expect(find.text('Electronics is coming soon'), findsOneWidget);
  });

  testWidgets('pushed category screen shows a back control', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CategoriesScreen()));

    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets(
    'services list stays overflow-free on a narrow, large-text screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.4),
            ),
            child: const CategoriesScreen(showBackButton: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Food'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('home category section shows an empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoriesSection(
            categories: const <Category>[],
            selectedCategoryId: null,
            onCategorySelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('No categories found'), findsOneWidget);
  });

  testWidgets('section header supports an optional action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SectionHeader(title: 'Orders')),
      ),
    );

    expect(find.text('Orders'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });
}
