import 'package:chowflow/app/main_app_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bottom navigation preserves tab state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MainAppScreen(
          screens: const [
            _CounterTab(),
            Center(child: Text('Explore test tab')),
            Center(child: Text('Activity test tab')),
            Center(child: Text('Profile test tab')),
          ],
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('increment-tab-counter')));
    await tester.pump();
    expect(find.text('Count 1'), findsOneWidget);

    await tester.tap(find.text('Explore'));
    await tester.pump();
    expect(find.text('Explore test tab'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pump();
    expect(find.text('Count 1'), findsOneWidget);
    expect(find.byType(IndexedStack), findsOneWidget);
  });

  testWidgets('the activity route can open the shell on the Activity tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MainAppScreen(
          initialIndex: 2,
          screens: const [
            Center(child: Text('Home test tab')),
            Center(child: Text('Explore test tab')),
            Center(child: Text('Activity test tab')),
            Center(child: Text('Profile test tab')),
          ],
        ),
      ),
    );

    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.selectedIndex, 2);
    expect(find.text('Activity test tab'), findsOneWidget);
  });

  testWidgets(
    'switching to the Activity tab reloads it, but re-tapping it does not',
    (tester) async {
      var focusCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: MainAppScreen(
            onActivityTabFocused: () async {
              focusCount++;
            },
            screens: const [
              Center(child: Text('Home test tab')),
              Center(child: Text('Explore test tab')),
              Center(child: Text('Activity test tab')),
              Center(child: Text('Profile test tab')),
            ],
          ),
        ),
      );
      expect(focusCount, 0);

      await tester.tap(find.text('Explore'));
      await tester.pump();
      expect(focusCount, 0, reason: 'switching to a non-Activity tab');

      await tester.tap(find.text('Activity'));
      await tester.pump();
      expect(focusCount, 1);

      await tester.tap(find.text('Activity'));
      await tester.pump();
      expect(
        focusCount,
        1,
        reason:
            're-tapping the already-active Activity tab should not '
            'reload again',
      );

      await tester.tap(find.text('Home'));
      await tester.pump();
      await tester.tap(find.text('Activity'));
      await tester.pump();
      expect(focusCount, 2, reason: 'switching back to Activity reloads it');
    },
  );
}

class _CounterTab extends StatefulWidget {
  const _CounterTab();

  @override
  State<_CounterTab> createState() => _CounterTabState();
}

class _CounterTabState extends State<_CounterTab> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Count $_count'),
          IconButton(
            key: const Key('increment-tab-counter'),
            onPressed: () => setState(() => _count++),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
