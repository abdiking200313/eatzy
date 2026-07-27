import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/super_app/presentation/super_app_home_screen.dart';
import '../platform/activity/presentation/activity_screen.dart';
import '../screens/explore.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key, this.screens, this.initialIndex = 0})
    : assert(screens == null || screens.length == 4),
      assert(initialIndex >= 0 && initialIndex < 4);

  final List<Widget>? screens;
  final int initialIndex;

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
            setState(() => _selectedIndex = index);
          },
          destinations: [
            for (final item in _navigationItems)
              NavigationDestination(
                icon: Icon(item.icon, color: TwColors.textMuted),
                selectedIcon: Icon(item.icon, color: TwColors.white),
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
