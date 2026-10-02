import 'package:flutter/material.dart';

import '../../data/models/sales_report.dart';

/// List of top-selling items.
class BestSellersList extends StatelessWidget {
  const BestSellersList({super.key, required this.report});

  final SalesReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (report.topSellers.isEmpty) {
      return _emptyState(theme, 'No sales data');
    }

    return Column(
      children: report.topSellers.asMap().entries.map((entry) {
        final index = entry.key;
        final seller = entry.value;
        return Column(
          children: [
            if (index > 0)
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
            _SellerRow(seller: seller, rank: index + 1, theme: theme),
          ],
        );
      }).toList(),
    );
  }

  Widget _emptyState(ThemeData theme, String message) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _SellerRow extends StatelessWidget {
  const _SellerRow({
    required this.seller,
    required this.rank,
    required this.theme,
  });

  final TopSeller seller;
  final int rank;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank <= 3
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$rank',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: rank <= 3
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name and unit
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  seller.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${seller.quantity} ${seller.unit}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Revenue
          Text(
            seller.formattedRevenue,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
