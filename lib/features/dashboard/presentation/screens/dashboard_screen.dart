import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/presentation/providers/order_provider.dart';
import '../providers/notification_provider.dart';

/// The Home tab.
///
/// Deliberately a thin screen: the AppBar carries the account actions, and the
/// body is the current order plus the one shortcut a counter reaches for
/// mid-sale -- scanning a prescription. Inventory counting and sales reporting
/// both live on their own tabs, so nothing about either is repeated here.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthProvider, bool>((a) => a.isAdmin);
    final unread = context.select<NotificationsProvider, int>(
      (p) => p.unreadCount,
    );

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 48,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 10, bottom: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8F4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/baseIcon.png',
                fit: BoxFit.cover,
                semanticLabel: 'PharmaGuide logo',
              ),
            ),
          ),
        ),
        title: const Text("Wilma Pharmacy's"),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          // Only an admin sees the way into the workspace; everyone else
          // has no business there and no door to it.
          if (isAdmin)
            IconButton(
              tooltip: 'Admin',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => context.pushNamed('admin'),
            ),
          // The one search affordance on this screen: opens the full-screen
          // finder, which browses every screen by name.
          IconButton(
            tooltip: 'Search screens',
            icon: const Icon(Icons.manage_search),
            onPressed: () => context.pushNamed('finder'),
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: Badge.count(
              count: unread,
              isLabelVisible: unread > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => context.pushNamed('home-notifications'),
          ),
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.pushNamed('home-profile'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        children: [
          Row(
            children: [
              Expanded(
                flex: 6,
                child: _CurrentOrderStrip(
                  onTap: () => context.goNamed('new-sale'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 42,
                  child: FilledButton(
                    onPressed: () => context.goNamed('new-sale'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1678ED),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 18),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'New sale',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _QuickAction(
            icon: Icons.document_scanner_outlined,
            label: 'Scan',
            onTap: () => context.pushNamed('home-scan'),
          ),
        ],
      ),
    );
  }
}

class _CurrentOrderStrip extends StatelessWidget {
  const _CurrentOrderStrip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (count, total) = context.select<OrderProvider, (int, String)>(
      (order) => (order.itemCount, order.formattedTotal),
    );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              const Icon(
                Icons.shopping_cart_outlined,
                color: Color(0xFF1680F5),
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 0
                          ? 'Current order is empty'
                          : 'Current order · ${count == 1 ? '1 item' : '$count items'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (count > 0)
                      Text(
                        '$total so far',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFF1680F5),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}