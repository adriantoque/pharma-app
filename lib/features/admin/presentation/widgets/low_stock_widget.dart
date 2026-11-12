import 'package:flutter/material.dart';

import '../../../reports/data/models/stock_alert.dart';

/// A widget displaying low stock alerts for the admin dashboard.
///
/// Shows items that are below their reorder level, with critical items
/// highlighted at the top of the list. The reorder level is a computed
/// target -- coverage days of demand at the item's selling rate, floored at
/// the store's low-stock threshold -- so the deficit badge answers "how many
/// units do I need to cover the window", not "how far below a made-up
/// constant".
class LowStockWidget extends StatelessWidget {
  const LowStockWidget({
    required this.lowStockAlerts,
    this.onManageStock,
    super.key,
  });

  final List<StockAlert> lowStockAlerts;

  /// Where "Manage Stock" leads, typically the inventory screen. The button
  /// does not render without one: a button whose tap does nothing reads as a
  /// failure, and this widget should not invent a route.
  final VoidCallback? onManageStock;

  /// Builds the list tile for a single stock alert.
  Widget _buildAlertTile(BuildContext context, StockAlert alert) {
    final isCritical = alert.isCritical;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      color: isCritical ? scheme.errorContainer : scheme.secondaryContainer,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCritical ? scheme.onErrorContainer : scheme.onSecondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              // An uncounted line has no count to show, and showing 0 would
              // state a fact nobody measured.
              alert.isStockUncounted
                  ? '?'
                  : alert.currentStock >= 10
                      ? alert.currentStock.toString()
                      : '<10',
              style: TextStyle(
                color: isCritical ? scheme.onErrorContainer : scheme.onSecondaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        title: Text(
          alert.name,
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: isCritical ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          // min, not the default max: a max-width Row inside a ListTile slot
          // asks for the whole tile width and trips the trailing/leading
          // layout assertion.
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              alert.isStockUncounted
                  ? 'Stock: not counted'
                  : 'Stock: ${alert.currentStock}',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
            // The observed rate, when velocity was behind this target: it is
            // what makes the reorder number checkable against the counter's
            // own sense of how fast the item moves.
            if (alert.formattedUnitsPerDay != null) ...[
              const SizedBox(width: 4),
              Text(
                '~${alert.formattedUnitsPerDay}/day',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
            const SizedBox(width: 4),
            Tooltip(
              message: alert.coverageDays == null
                  ? 'Below reorder level by ${alert.deficit} units'
                  : 'Sells about ${alert.formattedUnitsPerDay}/day; '
                      'reorder ${alert.deficit} units to cover '
                      '${alert.coverageDays} days',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isCritical ? scheme.errorContainer : scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${alert.deficit}+',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Reorder: ${alert.reorderLevel}',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: scheme.outline,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (lowStockAlerts.isEmpty) {
      return _emptyState(scheme);
    }

    // Sort by criticality (critical first), then by deficit
    final sortedAlerts = List<StockAlert>.from(lowStockAlerts);
    sortedAlerts.sort((a, b) {
      if (a.isCritical && !b.isCritical) return -1;
      if (!a.isCritical && b.isCritical) return 1;
      return b.deficit.compareTo(a.deficit);
    });

    return Card(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Low Stock Alerts',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '(${lowStockAlerts.length} items)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // List of alerts. Sized to its contents rather than expanded: this
            // widget is rendered inside the dashboard's scrolling ListView,
            // where an Expanded child has no height to divide up.
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedAlerts.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _buildAlertTile(context, sortedAlerts[index]),
            ),

            // Action button if there are critical items and somewhere to
            // send the admin: previously a no-op stub, which read as a
            // broken button every time the list had a critical row.
            if (sortedAlerts.any((alert) => alert.isCritical) &&
                onManageStock != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton.icon(
                  onPressed: onManageStock,
                  icon: const Icon(Icons.shopping_basket),
                  label: const Text('Manage Stock'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.errorContainer,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_outlined,
            size: 48,
            color: scheme.outline,
          ),
          const SizedBox(height: 8),
          Text(
            'No low stock alerts',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'All items are above reorder level',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}