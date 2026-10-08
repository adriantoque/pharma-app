import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/search/data/sync/sync_status.dart';
import '../../features/search/presentation/providers/medicine_provider.dart';
import '../widgets/offline_banner.dart';
import '../widgets/offline_mode_banner.dart';

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
  /// The order must match the branch order in `app_router.dart`, because
  /// [StatefulNavigationShell.goBranch] takes an index, not a route name. The
  /// Admin entry is only present for an admin, and it is always last, so an
  /// index below it never shifts.
  ///
  /// Public so tests can assert on the count and labels without pumping the
  /// whole shell; the admin tab is added on top of this list at build time.
  static const List<NavigationDestination> destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.inventory_2_outlined),
      selectedIcon: Icon(Icons.inventory_2),
      label: 'Inventory',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: 'Orders',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: 'Reports',
    ),
  ];

  static const NavigationDestination _adminDestination = NavigationDestination(
    icon: Icon(Icons.admin_panel_settings_outlined),
    selectedIcon: Icon(Icons.admin_panel_settings),
    label: 'Admin',
  );

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthProvider, bool>((a) => a.isAdmin);
    final visibleDestinations = <NavigationDestination>[
      ...destinations,
      if (isAdmin) _adminDestination,
    ];

    // If the role dropped to non-admin while the Admin branch was selected --
    // a demotion that arrived on a refresh, say -- the current index would
    // point past the end of the shorter list. Falling back to Home is the
    // safe reading.
    final currentIndex =
        navigationShell.currentIndex < visibleDestinations.length
            ? navigationShell.currentIndex
            : 0;

    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: navigationShell,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OfflineModeBanner(),
          OfflineBanner(
            status: context.select<MedicineProvider, SyncStatus>(
              (provider) => provider.syncStatus,
            ),
          ),
          NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            destinations: visibleDestinations,
          ),
        ],
      ),
    );
  }
}
