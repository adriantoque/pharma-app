import 'package:flutter/material.dart';

import '../../data/models/expiry_alert.dart';

/// List of expiring items.
class ExpiryList extends StatelessWidget {
  const ExpiryList({super.key, required this.alerts});

  final List<ExpiryAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (alerts.isEmpty) {
      return _emptyState(theme, 'No items expiring within 90 days');
    }

    return Column(
      children: alerts.asMap().entries.map((entry) {
        final index = entry.key;
        final alert = entry.value;
        return Column(
          children: [
            if (index > 0)
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
            _ExpiryAlertRow(alert: alert, theme: theme),
          ],
        );
      }).toList(),
    );
  }

  Widget _emptyState(ThemeData theme, String message) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpiryAlertRow extends StatelessWidget {
  const _ExpiryAlertRow({required this.alert, required this.theme});

  final ExpiryAlert alert;
  final ThemeData theme;

  Color get _badgeColor {
    return switch (alert.severity) {
      ExpirySeverity.expired => theme.colorScheme.error,
      ExpirySeverity.critical => theme.colorScheme.error,
      ExpirySeverity.warning => theme.colorScheme.tertiary,
      ExpirySeverity.ok => theme.colorScheme.outline,
    };
  }

  String get _badgeText {
    return switch (alert.severity) {
      ExpirySeverity.expired => 'Expired',
      ExpirySeverity.critical => '${alert.daysUntilExpiry} days',
      ExpirySeverity.warning => '${alert.daysUntilExpiry} days',
      ExpirySeverity.ok => '${alert.daysUntilExpiry} days',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  alert.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${alert.quantity} units, expires ${alert.formattedExpiryDate}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Days badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _badgeColor),
            ),
            child: Text(
              _badgeText,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: _badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
