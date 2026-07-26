import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../screens/cart.dart';
import '../screens/categories.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key, this.screens})
    : assert(screens == null || screens.length == 4);

  final List<Widget>? screens;

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _selectedIndex = 0;

  static const List<_NavigationItem> _navigationItems = [
    _NavigationItem(label: 'Home', icon: Icons.home, screen: HomeScreen()),
    _NavigationItem(
      label: 'Categories',
      icon: Icons.category,
      screen: CategoriesScreen(showBackButton: false),
    ),
    _NavigationItem(
      label: 'Cart',
      icon: Icons.shopping_cart,
      screen: CartScreen(),
    ),
    _NavigationItem(
      label: 'Profile',
      icon: Icons.person,
      screen: ProfileScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final screens =
        widget.screens ??
        _navigationItems.map((item) => item.screen).toList(growable: false);

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: TwColors.bg,
        selectedItemColor: TwColors.primary,
        unselectedItemColor: TwColors.textMuted,
        items: _navigationItems
            .map(
              (item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                label: item.label,
              ),
            )
            .toList(),
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
