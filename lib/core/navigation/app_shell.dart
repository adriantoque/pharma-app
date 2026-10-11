import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/search/data/sync/sync_status.dart';
import '../../features/search/presentation/providers/medicine_provider.dart';
import '../widgets/offline_banner.dart';
import '../widgets/offline_mode_banner.dart';

/// Hosts the persistent bottom navigation bar for the signed-in area.
///
/// Wrapping [StatefulShellRoute.indexedStack] in a Scaffold is what puts the
/// [NavigationBar] below every tab: each branch keeps its own navigator, so a
/// tab's stack and scroll position survive switching to another tab and back.
///
/// Five destinations, always. The Admin workspace is a full-screen route
/// outside the shell rather than a tab -- it has a different job from the
/// tabs around it, and an admin who enters it is not switching between work
/// and the rest of the app.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Outlined when unselected, filled when selected. Material 3 convention.
  ///
  /// The order must match the branch order in `app_router.dart`, because
  /// [StatefulNavigationShell.goBranch] takes an index, not a route name.
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
      icon: Icon(Icons.medication_outlined),
      selectedIcon: Icon(Icons.medication),
      label: 'Medicine',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: true,
        // The NavigationBar already applies its own bottom inset.
        bottom: false,
        child: navigationShell,
      ),
      // The banner goes above the bar rather than below it: a connection notice
      // belongs with the content, and the bar is the one thing on screen that
      // must stay exactly where it is while the user is typing a count.
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
            selectedIndex: navigationShell.currentIndex,
            // Tapping the already-active tab returns it to its root, so a user
            // who drilled into a sub-screen is not stranded there.
            onDestinationSelected: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            destinations: destinations,
          ),
        ],
      ),
    );
  }
}
