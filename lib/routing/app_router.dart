import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/navigation/app_shell.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/presentation/screens/auth_landing_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/dashboard/presentation/screens/expiring_meds_screen.dart';
import '../features/dashboard/presentation/screens/inventory_screen.dart';
import '../features/reports/presentation/screens/reports_screen.dart';
import '../features/orders/presentation/screens/orders_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/scan/presentation/screens/scan_screen.dart';
import '../features/sales/presentation/screens/new_sale_screen.dart';

abstract final class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String inventory = '/inventory';
  static const String orders = '/orders';
  static const String reports = '/reports';

  /// Children of Home, pushed on the Home branch so the back arrow returns to
  /// the tile the user tapped from.
  ///
  /// Documentation only. A `GoRoute` nested under `home` is declared with a
  /// *relative* path, so the route that actually resolves is `home` plus the
  /// child's own literal -- not the string below. These are here so the pushed
  /// pages can be read off without tracing the router.
  static const String homeExpiring = '/home/expiring';
  static const String homeScan = '/home/scan';
  static const String homeProfile = '/home/profile';
  static const String newSale = '/new-sale';
}

/// Builds the app router. The caller owns the returned instance and is
/// responsible for disposing it, which is why this is a factory rather than a
/// global — a global GoRouter is never disposed, survives hot restart, and
/// leaks navigation state between widget tests.
GoRouter createAppRouter({required Listenable refreshListenable}) {
  return GoRouter(
    // No '/' route: the signed-in area is a shell whose branches own their own
    // paths, so the app starts on the first branch directly.
        initialLocation: AppRoutes.home,
    // The provider is its own refresh Listenable, so an auth change re-runs the
    // redirect below without a ChangeNotifier bridge.
    refreshListenable: refreshListenable,
    redirect: (context, state) async {
      final auth = context.read<AuthProvider>();

      // Hold routing until the persisted session has been resolved. The router
      // is created as soon as the provider graph is built, so on a cold start
      // the status really is still unknown here. Without this await, the login
      // screen paints for one frame before bouncing a signed-in user onward.
      if (auth.status == AuthStatus.unknown) {
        await auth.ready;
      }

      final atLogin = state.matchedLocation == AppRoutes.login;

      switch (auth.status) {
        case AuthStatus.unauthenticated:
          return atLogin ? null : AppRoutes.login;
        case AuthStatus.authenticated:
          return atLogin ? AppRoutes.home : null;
        case AuthStatus.offline:
          return atLogin ? AppRoutes.home : null;
        case AuthStatus.unknown:
          return null;
      }
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const AuthLandingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: 'home',
                builder: (context, state) => const DashboardScreen(),
                // Nested under Home so each tile pushes a page onto the Home
                // branch: the bottom bar keeps Home selected and the back arrow
                // has somewhere to go. Inventory and Reports are tabs in their own
                // right, so they are top-level branches below instead.
                routes: [
                  GoRoute(
                    path: 'expiring',
                    name: 'home-expiring',
                    builder: (context, state) => const ExpiringMedsScreen(),
                  ),
                  GoRoute(
                    path: 'scan',
                    name: 'home-scan',
                    builder: (context, state) => const ScanScreen(),
                  ),
                  GoRoute(
                    path: 'profile',
                    name: 'home-profile',
                    builder: (context, state) => const ProfileScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.inventory,
                name: 'inventory',
                builder: (context, state) => const InventoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.orders,
                name: 'orders',
                builder: (context, state) => const OrdersScreen(),
              ),
              GoRoute(
                path: AppRoutes.newSale,
                name: 'new-sale',
                builder: (context, state) => const NewSaleScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reports,
                name: 'reports',
                builder: (context, state) => const ReportsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    // Reachable from either side of the auth redirect, so it cannot assume the
    // shell -- and therefore the artwork -- is mounted behind it.
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Page not found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                state.uri.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.goNamed('home'),
                child: const Text('Go to home'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
