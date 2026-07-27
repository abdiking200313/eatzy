import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/config/theme.dart';
import 'package:chowflow/widgets/add_to_cart_button.dart';
import 'package:chowflow/widgets/zivo_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Zivo logo stacks the mark above the wordmark', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: Center(child: ZivoLogo(height: 34))),
      ),
    );

    final mark = find.descendant(
      of: find.byType(ZivoLogo),
      matching: find.byType(CustomPaint),
    );
    final wordmark = find.text('zivo');

    expect(mark, findsOneWidget);
    expect(wordmark, findsOneWidget);
    expect(
      tester.getBottomLeft(mark).dy,
      lessThan(tester.getTopLeft(wordmark).dy),
    );
    expect(find.bySemanticsLabel('Zivo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('service theme applies the service palette throughout a route', (
    tester,
  ) async {
    late ThemeData resolvedTheme;
    late ZivoServiceColors resolvedColors;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ZivoServiceTheme(
          serviceId: ServiceId.grocery,
          child: Builder(
            builder: (context) {
              resolvedTheme = Theme.of(context);
              resolvedColors = context.serviceColors;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      ),
    );

    expect(resolvedColors, ServiceThemes.grocery);
    expect(resolvedTheme.colorScheme.primary, ServiceThemes.grocery.accent);
    expect(
      resolvedTheme.scaffoldBackgroundColor,
      ServiceThemes.grocery.background,
    );
  });

  testWidgets('shared add-to-cart control has one trailing cart glyph', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ZivoServiceTheme(
          serviceId: ServiceId.pharmacy,
          child: Scaffold(
            body: Align(
              alignment: Alignment.centerRight,
              child: AddToCartButton(
                tooltip: 'Add medicine to cart',
                onPressed: () => taps++,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.add_shopping_cart_rounded), findsOneWidget);
    expect(find.byTooltip('Add medicine to cart'), findsOneWidget);

    await tester.tap(find.byType(AddToCartButton));
    expect(taps, 1);
  });
}
