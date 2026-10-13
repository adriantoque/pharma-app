import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/navigation/app_shell.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/presentation/screens/auth_landing_screen.dart';
import '../features/auth/presentation/screens/role_login_screen.dart';
import '../features/auth/domain/user_role.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/dashboard/presentation/screens/expiring_meds_screen.dart';
import '../features/inventory/presentation/screens/inventory_screen.dart';
import '../features/search/presentation/screens/medicine_screen.dart';
import '../features/dashboard/presentation/screens/notifications_screen.dart';
import '../features/reports/presentation/screens/reports_screen.dart';
import '../features/orders/presentation/screens/orders_screen.dart';
import '../features/orders/presentation/screens/order_history_screen.dart';
import '../features/profile/presentation/screens/about_screen.dart';
import '../features/profile/presentation/screens/appearance_screen.dart';
import '../features/profile/presentation/screens/permissions_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/scan/presentation/screens/scan_screen.dart';
import '../features/finder/presentation/screens/finder_screen.dart';
import '../features/sales/presentation/screens/new_sale_screen.dart';
import '../features/sales/domain/payment_method.dart';
import '../features/sales/presentation/screens/cart_screen.dart';
import '../features/admin/presentation/screens/admin_home_screen.dart';
import '../features/admin/presentation/screens/activity_log_screen.dart';
import '../features/admin/presentation/screens/users_screen.dart';

abstract final class AppRoutes {
  static const String login = '/login';
  static const String adminLogin = '/admin-login';
  static const String staffLogin = '/staff-login';
  static const String home = '/home';
  static const String medicines = '/medicines';
  static const String orders = '/orders';
  static const String finder = '/finder';

  /// Legacy top-level paths. Kept only so old links and notifications
  /// redirect to the admin workspace instead of failing.
  static const String inventory = '/inventory';
  static const String reports = '/reports';

  /// The admin workspace, outside the shell. An admin never leaves it.
  static const String admin = '/admin';
  static const String adminUsers = '/admin/users';
  static const String adminInventory = '/admin/inventory';
  static const String adminReports = '/admin/reports';
  static const String adminActivity = '/admin/activity';

  /// Children of Home, pushed on the Home branch so the back arrow returns to
  /// the tile the user tapped from.
  ///
  /// Documentation only. A `GoRoute` nested under `home` is declared with a
  /// *relative* path, so the route that actually resolves is `home` plus the
  /// child's own literal, not the string below.
  static const String homeExpiring = '/home/expiring';
  static const String homeScan = '/home/scan';
  static const String homeSymptomGuide = '/home/symptom-guide';
  static const String homeSymptomDetail = '/home/symptom-guide/:symptomId';
  static const String homeProfile = '/home/profile';
  static const String homeProfileAppearance = '/home/profile/appearance';
  static const String homeNotifications = '/home/notifications';
  static const String newSale = '/new-sale';
}

/// Creates the router for the whole app.
///
/// The role split is the one piece of state that matters here: an admin is
/// held in the `/admin` subtree and never reaches the staff shell, and a staff
/// member (or guest) is held out of it. The redirect runs on every navigation,
/// so a role that changes mid-session is enforced on the next tap without any
/// screen having to know the rules.
GoRouter createAppRouter({required Listenable refreshListenable}) {
  return GoRouter(
    // The shell owns the bottom bar, and its first branch is Home. Starting
    // anywhere else would paint a different tab for a frame before the
    // redirect below corrected it.
    initialLocation: AppRoutes.home,
    refreshListenable: refreshListenable,
    redirect: (context, state) async {
      final auth = context.read<AuthProvider>();

      // Hold routing until the persisted session has been resolved. Without
      // this await, the login screen paints for one frame before bouncing a
      // signed-in user onward.
      if (auth.status == AuthStatus.unknown) {
        await auth.ready;
      }

      final location = state.matchedLocation;
      final atAuthScreen =
          location == AppRoutes.login ||
          location == AppRoutes.adminLogin ||
          location == AppRoutes.staffLogin;
      final atAdmin =
          location == AppRoutes.admin ||
          location.startsWith('${AppRoutes.admin}/');

      switch (auth.status) {
        case AuthStatus.unauthenticated:
          return atAuthScreen ? null : AppRoutes.login;

        case AuthStatus.authenticated:
          if (auth.isAdmin) {
            // Admins live in the admin workspace. The staff shell is
            // unreachable on purpose.
            return atAdmin ? null : AppRoutes.admin;
          }
          // Staff may not enter the admin workspace.
          if (atAdmin) return AppRoutes.home;
          // Just signed in on one of the doors: land on Home.
          if (atAuthScreen) return AppRoutes.home;
          return null;

        case AuthStatus.offline:
          // Guest mode: no admin access, and the auth screens are out of
          // reach once a session has started.
          if (atAdmin || atAuthScreen) return AppRoutes.home;
          return null;

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
      GoRoute(
        path: AppRoutes.adminLogin,
        name: 'admin-login',
        builder: (context, state) =>
            const RoleLoginScreen(role: UserRole.admin),
      ),
      GoRoute(
        path: AppRoutes.staffLogin,
        name: 'staff-login',
        builder: (context, state) =>
            const RoleLoginScreen(role: UserRole.staff),
      ),
      GoRoute(
        path: AppRoutes.finder,
        name: 'finder',
        builder: (context, state) =>
            FinderScreen(onNavigate: (entry) => context.go(entry.routePath)),
      ),

      // Legacy paths. Admins are sent to the admin workspace copy of the
      // screen; everyone else is sent Home. No builder, so nothing renders
      // for a moment.
      GoRoute(
        path: AppRoutes.inventory,
        name: 'legacy-inventory',
        redirect: (context, state) => context.read<AuthProvider>().isAdmin
            ? AppRoutes.adminInventory
            : AppRoutes.home,
      ),
      GoRoute(
        path: AppRoutes.reports,
        name: 'legacy-reports',
        redirect: (context, state) => context.read<AuthProvider>().isAdmin
            ? AppRoutes.adminReports
            : AppRoutes.home,
      ),

      // The admin workspace, outside the shell. Inventory and Reports are
      // admin-only, so they live here rather than in the staff shell.
      GoRoute(
        path: AppRoutes.admin,
        name: 'admin',
        builder: (context, state) => const AdminHomeScreen(),
        routes: [
          GoRoute(
            path: 'users',
            name: 'admin-users',
            builder: (context, state) => const UsersScreen(),
          ),
          GoRoute(
            path: 'inventory',
            name: 'admin-inventory',
            builder: (context, state) => const InventoryScreen(),
          ),
          GoRoute(
            path: 'reports',
            name: 'admin-reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: 'activity',
            name: 'admin-activity',
            builder: (context, state) => const ActivityLogScreen(),
          ),
        ],
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        // Branch order must match AppShell.destinations exactly:
        // 0 Home, 1 Medicine, 2 Orders.
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: 'home',
                builder: (context, state) => const DashboardScreen(),
                // Nested under Home so each tile pushes a page onto the Home
                // branch: the bottom bar keeps Home selected and the back
                // arrow has somewhere to go.
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
                    routes: [
                      GoRoute(
                        path: 'appearance',
                        name: 'home-profile-appearance',
                        builder: (context, state) => const AppearanceScreen(),
                      ),
                      GoRoute(
                        path: 'about',
                        name: 'home-profile-about',
                        builder: (context, state) => const AboutScreen(),
                      ),
                      GoRoute(
                        path: 'permissions',
                        name: 'home-profile-permissions',
                        builder: (context, state) => const PermissionsScreen(),
),
                ],

                GoRoute(
                  path: AppRoutes.homeSymptomGuide,
                  name: 'home-symptom-guide',
                  builder: (context, state) => const SymptomSearchScreen(),
                ),
                GoRoute(
                  path: AppRoutes.homeSymptomDetail,
                  name: 'home-symptom-detail',
                  builder: (context, state) {
                    final symptomId = state.pathParameters['symptomId'];
                    return SymptomDetailScreen(symptomId: symptomId!);
                  },
                ),
                  ),
                  GoRoute(
                    path: 'notifications',
                    name: 'home-notifications',
                    builder: (context, state) => const NotificationsScreen(),
                  ),
                ],
              ),
              // New Sale sits beside Home in the same branch so the Home tab
              // stays selected during a sale. Its cart is nested inside it
              // because the cart is part of the sale.
              GoRoute(
                path: AppRoutes.newSale,
                name: 'new-sale',
                builder: (context, state) => const NewSaleScreen(),
                routes: [
                  GoRoute(
                    path: 'cart',
                    name: 'new-sale-cart',
                    builder: (context, state) {
                      final payment =
                          state.extra as PaymentMethod? ??
                          PaymentMethod.cashOnHand;
                      return CartScreen(initialPayment: payment);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.medicines,
                name: 'medicines',
                builder: (context, state) => const MedicineScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.orders,
                name: 'orders',
                builder: (context, state) => const OrdersScreen(),
                routes: [
                  // History lives on the same branch as the list it belongs
                  // to, so the back arrow returns to the pending list.
                  GoRoute(
                    path: 'history',
                    name: 'orders-history',
                    builder: (context, state) => const OrderHistoryScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    // Reachable from either side of the auth redirect, so it cannot assume the
    // shell is mounted behind it.
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
