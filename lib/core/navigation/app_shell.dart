import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/app_background.dart';
import '../widgets/content_panel.dart';

/// Hosts the persistent bottom navigation bar for the signed-in area.
///
/// Wrapping [StatefulShellRoute.indexedStack] in a Scaffold is what puts the
/// [NavigationBar] below every tab: each branch keeps its own navigator, so a
/// tab's stack and scroll position survive switching to another tab and back.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Outlined when unselected, filled when selected. Material 3 convention.
  ///
  /// The order here must match the branch order in `app_router.dart`, because
  /// [StatefulNavigationShell.goBranch] takes an index, not a route name.
  static const List<NavigationDestination> destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.search_outlined),
      selectedIcon: Icon(Icons.search),
      label: 'Search',
    ),
    NavigationDestination(
      icon: Icon(Icons.qr_code_scanner_outlined),
      selectedIcon: Icon(Icons.qr_code_scanner),
      label: 'Scan',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: 'Orders',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // The background lives here rather than above the Navigator so that it
    // covers exactly the signed-in area. The login route sits outside this
    // shell, so it gets a plain surface instead of the artwork.
    return AppBackground(
      child: Scaffold(
        // The status bar inset has to be consumed before the panel's own top
        // margin is applied. The window draws under the bar, so a bare 14dp
        // margin put the panel's edge, corners and shadow underneath the clock,
        // signal and battery.
        //
        // SafeArea rather than a raw MediaQuery read because it consumes the
        // inset: each tab's own AppBar then sees padding.top == 0 instead of
        // adding a second 24dp of its own.
        body: SafeArea(
          top: true,
          // The NavigationBar already applies its own bottom inset.
          bottom: false,
          child: ContentPanel(child: navigationShell),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          // Tapping the already-active tab returns it to its root, so a user who
          // drilled into a sub-screen is not stranded there.
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          destinations: destinations,
        ),
      ),
    );
  }
}
