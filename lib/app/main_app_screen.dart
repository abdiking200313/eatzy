import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/theme.dart';
import '../platform/activity/presentation/activity_controller.dart';

/// The persistent shell around the bottom-nav tabs (Home, Explore, Activity,
/// Profile) and the food/grocery/pharmacy vertical branches.
///
/// [navigationShell] is supplied by `StatefulShellRoute.indexedStack` in
/// `app_router.dart` — it keeps every branch's own navigator (and therefore
/// its scroll position, in-flight futures, and back stack) alive in an
/// `IndexedStack` behind the scenes, so switching branches never rebuilds
/// this widget or discards the other branches' state. See issue #67.
class MainAppScreen extends StatefulWidget {
  const MainAppScreen({
    super.key,
    required this.navigationShell,
    this.onActivityTabFocused,
  });

  final StatefulNavigationShell navigationShell;

  /// Called whenever the bottom navigation switches *to* the Activity tab
  /// (index [activityTabIndex]). Defaults to [ActivityController.instance]'s
  /// `load()` so the Activity feed picks up server-side status changes
  /// (courier updates, etc. — see issue #64) instead of only ever showing
  /// whatever was loaded at app startup. Overridable so tests can observe
  /// the reload without a real [ActivityController].
  final Future<void> Function()? onActivityTabFocused;

  /// Index of the Activity tab within [_navigationItems].
  static const int activityTabIndex = 2;

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  static const List<_NavigationItem> _navigationItems = [
    _NavigationItem(label: 'Home', icon: Icons.home_outlined),
    _NavigationItem(label: 'Explore', icon: Icons.explore_outlined),
    _NavigationItem(label: 'Activity', icon: Icons.receipt_long_outlined),
    _NavigationItem(label: 'Profile', icon: Icons.person_outline),
  ];

  // The food/grocery/pharmacy verticals are additional shell branches beyond
  // these four (so entering one keeps this nav bar on screen instead of
  // stacking a full-screen route over it), but they aren't destinations of
  // their own in the bottom nav. While one of them is active, keep
  // highlighting whichever of the four primary tabs the user was last on,
  // rather than an out-of-range index or no selection at all.
  int _lastPrimaryIndex = 0;

  @override
  void initState() {
    super.initState();
    _syncLastPrimaryIndex();
  }

  @override
  void didUpdateWidget(covariant MainAppScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncLastPrimaryIndex();
  }

  void _syncLastPrimaryIndex() {
    final index = widget.navigationShell.currentIndex;
    if (index < _navigationItems.length) {
      _lastPrimaryIndex = index;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    final selectedIndex = currentIndex < _navigationItems.length
        ? currentIndex
        : _lastPrimaryIndex;

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: TwColors.white,
          border: Border(top: BorderSide(color: TwColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            final isSwitchingToActivity =
                index == MainAppScreen.activityTabIndex &&
                widget.navigationShell.currentIndex != index;
            widget.navigationShell.goBranch(
              index,
              initialLocation: index == widget.navigationShell.currentIndex,
            );
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
  const _NavigationItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
