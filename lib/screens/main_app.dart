import 'package:chowflow/screens/categories.dart';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'cart.dart';
//import 'categories.dart';
import 'home.dart';
import 'profile.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _selectedIndex = 0;

  static const List<_NavigationItem> _navigationItems = [
    _NavigationItem(
      label: 'Home',
      icon: Icons.home,
      screen: HomeScreen(),
    ),
    _NavigationItem(
      label: 'Categories',
      icon: Icons.category,
      screen: CategoriesScreen(),
    ),
    _NavigationItem(
      label: 'Cart',
      icon: Icons.shopping_cart,
      screen: CartScreenFull(),
    ),
    _NavigationItem(
      label: 'Profile',
      icon: Icons.person,
      screen: ProfileScreenFull(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _navigationItems[_selectedIndex].screen,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.outline,
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
