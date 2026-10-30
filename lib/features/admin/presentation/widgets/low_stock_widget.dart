import 'package:flutter/material.dart';

import '../../../reports/data/models/stock_alert.dart';

/// A widget displaying low stock alerts for the admin dashboard.
///
/// Shows items that are below their reorder level, with critical items
/// highlighted at the top of the list.
class LowStockWidget extends StatelessWidget {
  const LowStockWidget({
    required this.lowStockAlerts,
    super.key,
  });

  final List<StockAlert> lowStockAlerts;

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
              alert.currentStock >= 10 ? alert.currentStock.toString() : '<10',
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
              'Stock: ${alert.currentStock}',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: 'Below reorder level by ${alert.deficit} units',
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

            // Action button if there are critical items
            if (sortedAlerts.any((alert) => alert.isCritical))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to inventory or reorder screen
                    // In a full implementation
                  },
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