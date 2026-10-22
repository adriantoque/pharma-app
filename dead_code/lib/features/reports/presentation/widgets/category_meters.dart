import 'package:flutter/material.dart';

import '../../data/models/sales_report.dart';

/// Category sales with percentage meters.
class CategoryMeters extends StatelessWidget {
  const CategoryMeters({super.key, required this.report});

  final SalesReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (report.categorySales.isEmpty) {
      return _emptyState(theme, 'No category data');
    }

    return Column(
      children: report.categorySales.asMap().entries.map((entry) {
        final index = entry.key;
        final category = entry.value;
        return Column(
          children: [
            if (index > 0)
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
            _CategoryRow(category: category, theme: theme),
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

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.theme});

  final CategorySales category;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  category.category,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${category.percentage}%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: category.percentage / 100,
                backgroundColor: theme.colorScheme.primaryContainer,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
