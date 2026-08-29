import 'package:chowflow/app/main_app_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  // Builds the same branch shape as the real app (Home/Explore/Activity/
  // Profile), optionally with an extra branch representing a service
  // vertical (food/grocery/pharmacy) that isn't a bottom-nav destination of
  // its own — matching how app_router.dart wires MainAppScreen up to
  // StatefulShellRoute.indexedStack for issue #67.
  GoRouter buildTestRouter({
    required Widget homeTab,
    String initialLocation = '/home',
    bool withVerticalBranch = false,
  }) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainAppScreen(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [GoRoute(path: '/home', builder: (_, _) => homeTab)],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/explore',
                  builder: (_, _) =>
                      const Center(child: Text('Explore test tab')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/activity',
                  builder: (_, _) =>
                      const Center(child: Text('Activity test tab')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (_, _) =>
                      const Center(child: Text('Profile test tab')),
                ),
              ],
            ),
            if (withVerticalBranch)
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/vertical',
                    builder: (_, _) =>
                        const Center(child: Text('Vertical test tab')),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  testWidgets('bottom navigation preserves each branch\'s own state', (
    tester,
  ) async {
    final router = buildTestRouter(homeTab: const _CounterTab());
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.byKey(const Key('increment-tab-counter')));
    await tester.pump();
    expect(find.text('Count 1'), findsOneWidget);

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(find.text('Explore test tab'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Count 1'), findsOneWidget);
    expect(find.byType(IndexedStack), findsOneWidget);
  });

  testWidgets('an initial location resolves to its matching branch/tab', (
    tester,
  ) async {
    final router = buildTestRouter(
      homeTab: const Center(child: Text('Home test tab')),
      initialLocation: '/activity',
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.selectedIndex, 2);
    expect(find.text('Activity test tab'), findsOneWidget);
  });

  testWidgets(
    'entering a non-tab branch (e.g. a service vertical) keeps the shell '
    'and its nav bar on screen instead of stacking a full-screen route '
    'over it',
    (tester) async {
      final router = buildTestRouter(
        homeTab: Builder(
          builder: (context) => TextButton(
            onPressed: () => context.go('/vertical'),
            child: const Text('Open vertical'),
          ),
        ),
        withVerticalBranch: true,
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.tap(find.text('Open vertical'));
      await tester.pumpAndSettle();

      // The vertical's own screen is showing...
      expect(find.text('Vertical test tab'), findsOneWidget);
      // ...but the persistent shell/nav bar is still there, still showing
      // the four primary tabs, with Home (the tab the vertical was opened
      // from) still highlighted rather than an out-of-range index.
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);
      final navigation = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navigation.selectedIndex, 0);
    },
  );

  testWidgets(
    'switching to the Activity tab reloads it, but re-tapping it does not',
    (tester) async {
      var focusCount = 0;
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) => MainAppScreen(
              navigationShell: navigationShell,
              onActivityTabFocused: () async {
                focusCount++;
              },
            ),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/home',
                    builder: (_, _) =>
                        const Center(child: Text('Home test tab')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/explore',
                    builder: (_, _) =>
                        const Center(child: Text('Explore test tab')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/activity',
                    builder: (_, _) =>
                        const Center(child: Text('Activity test tab')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/profile',
                    builder: (_, _) =>
                        const Center(child: Text('Profile test tab')),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      expect(focusCount, 0);

      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();
      expect(focusCount, 0, reason: 'switching to a non-Activity tab');

      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
      expect(focusCount, 1);

      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
      expect(
        focusCount,
        1,
        reason:
            're-tapping the already-active Activity tab should not '
            'reload again',
      );

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
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
