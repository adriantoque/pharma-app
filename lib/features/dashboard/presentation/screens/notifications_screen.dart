import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/notification_model.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final notifications = context.watch<NotificationsProvider>().notifications;
    final filterProvider = context.watch<NotificationFilterProvider>();
    final selectedCategory = filterProvider.selectedCategory;
    final unreadCount = context.watch<NotificationsProvider>().unreadCount;
    final notifier = context.read<NotificationsProvider>();

    final filtered = selectedCategory == NotificationCategory.all
        ? notifications
        : notifications.where((n) => n.category == selectedCategory).toList();

    final counts = <NotificationCategory, int>{};
    for (final n in notifications) {
      counts[n.category] = (counts[n.category] ?? 0) + 1;
    }

    /// Marks the item read and goes wherever its [effectiveRoute] points.
    ///
    /// One handler for both the tile and the trailing button, so the two
    /// cannot drift into different behaviour: whichever the user taps, the
    /// notification is acknowledged and the app is taken to what it is about.
    /// `context.go` rather than `push`: a notification is a shortcut, not a
    /// drill-down, and going "back" to a list of things already seen is not
    /// where a user's next thought goes.
    void open(NotificationItem item) {
      notifier.markAsRead(item.id);
      final route = item.effectiveRoute;
      if (route != null) context.go(route);
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Notifications'),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Badge(
                label: Text('$unreadCount'),
                backgroundColor: theme.colorScheme.primary,
              ),
            ],
          ],
        ),
        actions: [
          if (notifications.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed: unreadCount == 0 ? null : notifier.markAllAsRead,
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'clear') {
                  _confirmClearAll(context, notifier);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20),
                      SizedBox(width: 8),
                      Text('Clear all'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            selected: selectedCategory,
            counts: counts,
            onSelected: (c) =>
                context.read<NotificationFilterProvider>().selectedCategory = c,
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? _EmptyNotificationsView(category: selectedCategory)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return Dismissible(
                        key: Key(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: theme.colorScheme.error,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: Icon(
                            Icons.delete_outline,
                            color: theme.colorScheme.onError,
                          ),
                        ),
                        onDismissed: (_) {
                          notifier.delete(item.id);
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text('Deleted "${item.title}"'),
                                behavior: SnackBarBehavior.floating,
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () => notifier.restore(item),
                                ),
                              ),
                            );
                        },
                        child: _NotificationTile(
                          item: item,
                          onTap: () => open(item),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearAll(
    BuildContext context,
    NotificationsProvider notifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.brandGreenSurface,
              foregroundColor: AppColors.brandGreen,
              side: const BorderSide(
                color: AppColors.brandGreenSurfaceBorder,
              ),
            ),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      notifier.clearAll();
    }
  }
}

class _FilterBar extends StatelessWidget {
  final NotificationCategory selected;
  final Map<NotificationCategory, int> counts;
  final ValueChanged<NotificationCategory> onSelected;

  const _FilterBar({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (final category in NotificationCategory.values) ...[
            FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(category.label),
                  if (counts[category] != null && counts[category]! > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '${counts[category]}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              selected: selected == category,
              showCheckmark: false,
              onSelected: (_) => onSelected(category),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotificationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = item.category.color(theme.colorScheme);
    final route = item.effectiveRoute;

    return ListTile(
      onTap: onTap,
      tileColor: item.isRead
          ? Colors.transparent
          : theme.colorScheme.primaryContainer.withValues(alpha: 0.08),
      leading: CircleAvatar(
        backgroundColor: categoryColor.withValues(alpha: 0.12),
        child: Icon(item.category.icon, color: categoryColor, size: 20),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          if (!item.isRead)
            Semantics(
              label: 'Unread',
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatRelativeTime(item.timestamp),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
      // A notification about a thing the user can act on offers the way
      // there. A notification that is only informational -- or one whose
      // category maps nowhere -- renders without a button rather than
      // offering one that does nothing.
      trailing: route == null
          ? null
          : TextButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.arrow_forward, size: 14),
              label: const Text('View details'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brandGreen,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
    );
  }
}

class _EmptyNotificationsView extends StatelessWidget {
  final NotificationCategory category;

  const _EmptyNotificationsView({required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            category.emptyMessage,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}