import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/low_stock_widget.dart';
import '../widgets/revenue_chart_widget.dart';
import '../../../reports/presentation/providers/reports_provider.dart';

/// Card showing admin greeting with welcome message.
class _GreetingCard extends StatelessWidget {
  const _GreetingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = context.select<AuthProvider, String?>((a) => a.user?.name);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: scheme.onPrimaryContainer.withValues(alpha: 0.15),
              child: Icon(
                Icons.admin_panel_settings,
                color: scheme.onPrimaryContainer,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Welcome back,',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name ?? 'Administrator',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Admin workspace: the only screen an administrator sees.
/// An admin is held here by the router's redirect and never reaches the
/// staff shell, so there is no "back to app" arrow -- there is nowhere to
/// go back to. The AppBar menu carries sign-out, which is the one way out
/// of the workspace short of closing the app.
///
/// A dashboard rather than a menu: an admin who opens this screen should be
/// able to see the shape of the team at a glance and the last few things that
/// happened, without tapping into each section first. The destinations are
/// still here, under the numbers they act on.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  @override
  void initState() {
    super.initState();
    // The dashboard shows figures from the same provider the Reports screen
    // reads, so it has to ask for them itself: an admin who never opens
    // Reports would otherwise see a permanent zero. Post-frame because the
    // load notifies listeners, and notifying during the first build is an
    // error.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ReportsProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    // watch, not read: the summary cards, chart and low-stock list all repaint
    // when a load lands.
    final reports = context.watch<ReportsProvider>();

    return Scaffold(
      appBar: AppBar(
        // No leading widget on purpose. An admin is pinned to this subtree;
        // an arrow back to the staff app would open a door the redirect
        // would immediately slam shut.
        automaticallyImplyLeading: false,
        title: const Text('Admin'),
        centerTitle: true,
        actions: [
          PopupMenuButton<_AdminMenuAction>(
            tooltip: 'More',
            onSelected: (action) => switch (action) {
              _AdminMenuAction.signOut => _confirmSignOut(context),
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _AdminMenuAction.signOut,
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Sign out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _GreetingCard(),

          const SizedBox(height: 16),

          // Summary cards row
          _SummaryCards(reports: reports),

          const SizedBox(height: 24),

          // Revenue trend
          _SectionHeader(title: 'Sales trend'),
          const SizedBox(height: 8),
          const RevenueGrowthChart(),

          const SizedBox(height: 24),

          // Quick actions
          _SectionHeader(title: 'Quick actions'),
          const SizedBox(height: 8),
          _QuickActions(),

          const SizedBox(height: 24),

          // Low stock alerts
          _SectionHeader(title: 'Low stock alerts'),
          const SizedBox(height: 8),
          _LowStockSection(reports: reports),

          const SizedBox(height: 24),

        ],
      ),
    );
  }

  /// Confirms and performs sign-out.
  /// The router's redirect sends the user to the login screen the moment the
  /// auth state flips, so nothing navigates here.
  Future<void> _confirmSignOut(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    // The dialog is a route of its own; the screen can be gone by the time it
    // closes.
    if (!context.mounted) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.logout();
    if (!success && auth.error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(auth.error ?? 'An unknown error occurred')),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Summary cards row
// ---------------------------------------------------------------------------

/// Row of summary cards: Sales, Inventory.
class _SummaryCards extends StatelessWidget {
  final ReportsProvider reports;

  const _SummaryCards({required this.reports});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        // Sales card
        Expanded(
          child: _SummaryCard(
            icon: Icons.bar_chart,
            label: 'Sales',
            value: _formatCurrency(context, reports.salesReport?.totalRevenue ?? 0),
            onTap: () => context.pushNamed('admin-reports'),
            color: scheme.primary,
          ),
        ),
        const SizedBox(width: 12),

        // Inventory card
        Expanded(
          child: _SummaryCard(
            icon: Icons.inventory,
            label: 'Low stock',
            value: reports.lowStockAlerts.length.toString(),
            onTap: () => context.pushNamed('admin-inventory'),
            color: scheme.secondary,
          ),
        ),
      ],
    );
  }

  String _formatCurrency(BuildContext context, int amount) {
    final pesos = amount / 100;
    return '₱${pesos.toStringAsFixed(2)}';
  }
}

/// A summary statistic card.
class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      color: scheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              // A fixed gap, not a Spacer: the cards sit in a Row inside the
              // dashboard's scrolling ListView, so their height is unbounded
              // and a flex child would ask for space that does not exist.
              const SizedBox(height: 12),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Low stock section
// ---------------------------------------------------------------------------

/// Section displaying low stock alerts from the reports provider.
class _LowStockSection extends StatelessWidget {
  final ReportsProvider reports;

  const _LowStockSection({required this.reports});

  @override
  Widget build(BuildContext context) {
    return LowStockWidget(
      lowStockAlerts: reports.lowStockAlerts,
      onManageStock: () => context.pushNamed('admin-inventory'),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick actions
// ---------------------------------------------------------------------------

/// Quick action tiles for the admin dashboard.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionTile(
          icon: Icons.bar_chart_outlined,
          title: 'Reports',
          subtitle: 'Sales and stock analytics',
          onTap: () => context.pushNamed('admin-reports'),
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.inventory_2_outlined,
          title: 'Inventory',
          subtitle: 'Manage stock, prices and expiry',
          onTap: () => context.pushNamed('admin-inventory'),
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.storefront_outlined,
          title: 'Store settings',
          subtitle: 'Name, hours, low-stock threshold',
          onTap: () => context.go('/admin/store-settings'),
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'View system alerts and updates',
          onTap: () => context.pushNamed('admin-notifications'),
        ),

      ],
    );
  }
}

/// One destination row.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: scheme.onSecondaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(title, style: theme.textTheme.titleMedium),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Menu actions
// ---------------------------------------------------------------------------

enum _AdminMenuAction { signOut }