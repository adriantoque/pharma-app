import 'package:flutter/material.dart';

import '../../domain/audit_event.dart';

/// One row of the activity log.
///
/// Shared by the Admin home preview and the full Activity log screen so the
/// two cannot drift: an entry reads the same whether it is one of the last
/// three or one of five hundred.
class ActivityRow extends StatelessWidget {
  const ActivityRow({super.key, required this.event});

  final AuditEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: scheme.secondaryContainer,
            child: Icon(
              iconFor(event.action),
              size: 16,
              color: scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  event.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${event.actorName} · ${relativeTime(event.at)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData iconFor(AuditAction action) => switch (action.category) {
    AuditCategory.users => Icons.people_outline,
    AuditCategory.settings => Icons.settings_outlined,
    AuditCategory.all => Icons.history_outlined,
  };

  /// Reads the same way the notification timestamps do. Kept local rather than
  /// shared: the notifications feature has its own copy, and a cross-feature
  /// import for one formatting function is not worth the coupling.
  static String relativeTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}
