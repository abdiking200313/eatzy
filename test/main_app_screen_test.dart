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
            Center(child: Text('Category test tab')),
            Center(child: Text('Cart test tab')),
            Center(child: Text('Profile test tab')),
          ],
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('increment-tab-counter')));
    await tester.pump();
    expect(find.text('Count 1'), findsOneWidget);

    await tester.tap(find.text('Categories'));
    await tester.pump();
    expect(find.text('Category test tab'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pump();
    expect(find.text('Count 1'), findsOneWidget);
    expect(find.byType(IndexedStack), findsOneWidget);
  });
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
