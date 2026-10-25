import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/orders/presentation/providers/order_provider.dart';
import '../../features/search/data/sync/sync_status.dart';
import '../../features/search/presentation/providers/medicine_provider.dart';
import '../widgets/offline_banner.dart';
import '../widgets/offline_mode_banner.dart';

/// Hosts the persistent bottom navigation bar for the signed-in staff area.
///
/// Wrapping [StatefulShellRoute.indexedStack] in a Scaffold is what puts the
/// [NavigationBar] below every tab: each branch keeps its own navigator, so a
/// tab's stack and scroll position survive switching to another tab and back.
///
/// Four destinations, the staff bar: New Sale, Symptoms and Scan SKU
/// plus Cart. The standalone catalogue and order screens are still routed,
/// but they are pushed as pages now, so they no longer need a tab of their
/// own. Inventory and Reports are admin-only and live in the admin workspace,
/// outside the shell.
///
/// Cart is the tab the app bar's cart icon and cart sheet were replaced by:
/// it carries the entry-count badge that icon used to show, and it taps
/// through to the same cart screen in its tab variant -- the one that has no
/// result contract with a sale screen.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Outlined when unselected, filled when selected. Material 3 convention.
  ///
  /// The order must match the branch order in `app_router.dart`, because
  /// [StatefulNavigationShell.goBranch] takes an index, not a route name.
  static const List<NavigationDestination> destinations = [
    NavigationDestination(
      icon: Icon(Icons.storefront_outlined),
      selectedIcon: Icon(Icons.storefront),
      label: 'New Sale',
    ),
    NavigationDestination(
      icon: Icon(Icons.medical_services_outlined),
      selectedIcon: Icon(Icons.medical_services),
      label: 'Symptoms',
    ),
    NavigationDestination(
      icon: Icon(Icons.qr_code_scanner_outlined),
      selectedIcon: Icon(Icons.qr_code_scanner),
      label: 'Scan SKU',
    ),
    NavigationDestination(
      icon: Icon(Icons.shopping_cart_outlined),
      selectedIcon: Icon(Icons.shopping_cart),
      label: 'Cart',
    ),
  ];

  /// Which destination is the Cart, so the icons can be rewrapped with the
  /// live item-count [Badge]. Same coupling as the destination order above:
  /// this must match the branch order in `app_router.dart`.
  static const int cartDestinationIndex = 3;

  /// Rewraps the Cart destination's icon in a [Badge.count]. The committed
  /// [destinations] list stays const so the index-coupling tests read it
  /// directly; the badge is applied at build time only, and only while the
  /// cart holds something, mirroring the badge the app bar used to hide.
  ///
  /// A [NavigationDestination] takes the *selected* icon as an [IconData],
  /// not a widget, so it cannot be wrapped: the count shows on the unselected
  /// icon, and the selected state advertises the same count in the Cart tab's
  /// own app bar title.
  static NavigationDestination _withCountBadge(
    NavigationDestination destination,
    int count,
  ) {
    return NavigationDestination(
      icon: Badge.count(count: count, child: destination.icon),
      selectedIcon: destination.selectedIcon,
      label: destination.label,
    );
  }

  @override
  Widget build(BuildContext context) {
    // The Cart entry carries the live count; watching it here means the bar
    // itself repaints on the same change that used to move the app bar badge.
    final cartCount = context.watch<OrderProvider>().itemCount;
    final destinations = cartCount > 0
        ? [
            for (var index = 0;
                index < AppShell.destinations.length;
                index++)
              index == AppShell.cartDestinationIndex
                  ? _withCountBadge(AppShell.destinations[index], cartCount)
                  : AppShell.destinations[index],
          ]
        : AppShell.destinations;

    return Scaffold(
      body: SafeArea(
        top: true,
        // The NavigationBar already applies its own bottom inset.
        bottom: false,
        child: navigationShell,
      ),
      // The banner goes above the bar rather than below it: a connection notice
      // belongs with the content, and the bar must stay where it is while the
      // user is typing.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const OfflineModeBanner(),
          OfflineBanner(
            status: context.select<MedicineProvider, SyncStatus>(
              (provider) => provider.syncStatus,
            ),
          ),
          NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            // The committed bar is white with a teal pill behind the
            // selected destination, independent of the app theme so the
            // staff POS keeps that look in dark mode too.
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFCBF1EC),
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
