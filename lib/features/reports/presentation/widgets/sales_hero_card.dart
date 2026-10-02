import 'package:flutter/material.dart';

import '../../data/models/report_range.dart';
import '../../data/models/sales_report.dart';

/// Hero card showing total revenue, profit, orders, and average bill.
class SalesHeroCard extends StatelessWidget {
  const SalesHeroCard({super.key, required this.report, required this.range});

  final SalesReport report;
  final ReportRange range;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            range == ReportRange.today
                ? 'Sales today'
                : 'Sales, last ${range.label}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            report.formattedTotalRevenue,
            style: theme.textTheme.displaySmall?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 42,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _FactItem(
                  label: 'Profit',
                  value: report.formattedProfit,
                  theme: theme,
                ),
              ),
              Expanded(
                child: _FactItem(
                  label: 'Customers served',
                  value: report.totalCustomers.toString(),
                  theme: theme,
                ),
              ),
              Expanded(
                child: _FactItem(
                  label: 'Average bill',
                  value: report.formattedAverageBill,
                  theme: theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FactItem extends StatelessWidget {
  const _FactItem({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onPrimary.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
            fontFamily: 'Bricolage Grotesque',
            fontSize: 24,
          ),
        ),
      ],
    );
  }
}
