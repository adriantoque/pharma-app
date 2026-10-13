import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The admin's notifications screen: shows system alerts and updates
/// relevant to the administrator role.
class AdminNotificationsScreen extends StatelessWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = _sampleNotifications();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.remove),
            tooltip: 'Mark all as read',
            onPressed: () {
              // In a full implementation, this would mark all notifications as read
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All notifications marked as read')),
              );
            },
          ),
        ],
      ),
      body: _NotificationsList(notifications: notifications),
    );
  }

  static List<_Notification> _sampleNotifications() {
    return const [
      _Notification(
        id: '1',
        title: 'Low Stock Alert',
        message: 'Amoxicillin 500mg is below minimum threshold',
        timestamp: '2 hours ago',
        category: AlertCategory.stock,
        effectiveRoute: '/admin/inventory',
      ),
      _Notification(
        id: '2',
        title: 'New User Registered',
        message: 'Dr. Smith has been added as a new admin',
        timestamp: 'Yesterday',
        category: AlertCategory.user,
        effectiveRoute: '/admin/users',
      ),
      _Notification(
        id: '3',
        title: 'Order Completed',
        message: 'Order #12345 has been successfully completed',
        timestamp: '3 days ago',
        category: AlertCategory.orders,
        effectiveRoute: '/orders',
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class _Notification {
  final String id;
  final String title;
  final String message;
  final String timestamp;
  final AlertCategory category;
  final String? effectiveRoute;

  const _Notification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.category,
    this.effectiveRoute,
  });
}

enum AlertCategory { stock, user, orders }

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _NotificationsList extends StatelessWidget {
  final List<_Notification> notifications;

  const _NotificationsList({
    required this.notifications,
  });

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return const _EmptyNotificationsView();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notif = notifications[index];
        return _NotificationTile(notification: notif);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tile
// ---------------------------------------------------------------------------

class _NotificationTile extends StatelessWidget {
  final _Notification notification;

  const _NotificationTile({
    required this.notification,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        final route = notification.effectiveRoute;
        if (route != null) {
          context.go(route);
        }
      },
      leading: _categoryIcon(notification.category, context),
      title: Text(notification.title),
      subtitle: Text(notification.message),
      trailing: notification.effectiveRoute != null
          ? Tooltip(
              message: 'View details',
              child: Icon(Icons.arrow_forward_ios, size: 12),
            )
          : null,
    );
  }

  Icon _categoryIcon(AlertCategory category, BuildContext ctx) {
    switch (category) {
      case AlertCategory.stock:
        return Icon(Icons.inventory, color: Theme.of(ctx).colorScheme.error);
      case AlertCategory.user:
        return Icon(Icons.person_add, color: Theme.of(ctx).colorScheme.primary);
      case AlertCategory.orders:
        return Icon(Icons.shopping_cart, color: Theme.of(ctx).colorScheme.secondary);
    }
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyNotificationsView extends StatelessWidget {
  const _EmptyNotificationsView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'You are up to date on all system alerts.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}