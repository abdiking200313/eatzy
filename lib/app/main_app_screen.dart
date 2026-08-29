import 'dart:async';

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/super_app/presentation/super_app_home_screen.dart';
import '../platform/activity/presentation/activity_controller.dart';
import '../platform/activity/presentation/activity_screen.dart';
import '../screens/explore.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({
    super.key,
    this.screens,
    this.initialIndex = 0,
    this.onActivityTabFocused,
  }) : assert(screens == null || screens.length == 4),
       assert(initialIndex >= 0 && initialIndex < 4);

  final List<Widget>? screens;
  final int initialIndex;

  /// Called whenever the bottom navigation switches *to* the Activity tab
  /// (index [activityTabIndex]). Defaults to [ActivityController.instance]'s
  /// `load()` so the Activity feed picks up server-side status changes
  /// (courier updates, etc. — see issue #64) instead of only ever showing
  /// whatever was loaded at app startup. Overridable so tests can observe
  /// the reload without a real [ActivityController].
  final Future<void> Function()? onActivityTabFocused;

  /// Index of the Activity tab within [_navigationItems] / a custom
  /// [screens] list.
  static const int activityTabIndex = 2;

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  late int _selectedIndex;

  static const List<_NavigationItem> _navigationItems = [
    _NavigationItem(
      label: 'Home',
      icon: Icons.home_outlined,
      screen: SuperAppHomeScreen(),
    ),
    _NavigationItem(
      label: 'Explore',
      icon: Icons.explore_outlined,
      screen: ExploreScreen(),
    ),
    _NavigationItem(
      label: 'Activity',
      icon: Icons.receipt_long_outlined,
      screen: ActivityScreen(),
    ),
    _NavigationItem(
      label: 'Profile',
      icon: Icons.person_outline,
      screen: ProfileScreen(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final screens =
        widget.screens ??
        _navigationItems.map((item) => item.screen).toList(growable: false);

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: TwColors.white,
          border: Border(top: BorderSide(color: TwColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            final isSwitchingToActivity =
                index == MainAppScreen.activityTabIndex &&
                _selectedIndex != index;
            setState(() => _selectedIndex = index);
            if (isSwitchingToActivity) {
              unawaited(
                (widget.onActivityTabFocused ??
                    ActivityController.instance.load)(),
              );
            }
          },
          destinations: [
            for (final item in _navigationItems)
              NavigationDestination(
                icon: Icon(item.icon, color: TwColors.textMuted),
                // No more selection-pill background behind the icon, so the
                // selected state is carried by icon color alone (label
                // color/weight already flips via navigationBarTheme).
                selectedIcon: Icon(item.icon, color: TwColors.primary),
                label: item.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _NavigationItem {
  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.screen,
  });

  final String label;
  final IconData icon;
  final Widget screen;
}
