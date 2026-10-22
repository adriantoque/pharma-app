import 'package:flutter/material.dart';

import '../../data/models/stock_alert.dart';

/// List of low stock items needing reorder.
class LowStockList extends StatelessWidget {
  const LowStockList({super.key, required this.alerts});

  final List<StockAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (alerts.isEmpty) {
      return _emptyState(theme, 'All items well stocked');
    }

    return Column(
      children: alerts.asMap().entries.map((entry) {
        final index = entry.key;
        final alert = entry.value;
        return Column(
          children: [
            if (index > 0)
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
            _StockAlertRow(alert: alert, theme: theme),
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
              Icons.inventory_2_outlined,
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

class _StockAlertRow extends StatelessWidget {
  const _StockAlertRow({required this.alert, required this.theme});

  final StockAlert alert;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = alert.currentStock == 0;

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
                if (alert.category != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    alert.category!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Stock count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isOutOfStock
                  ? theme.colorScheme.errorContainer
                  : theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isOutOfStock ? 'Out of stock' : '${alert.currentStock} left',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isOutOfStock
                    ? theme.colorScheme.onErrorContainer
                    : theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Reorder level
          Text(
            'Reorder: ${alert.reorderLevel}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
