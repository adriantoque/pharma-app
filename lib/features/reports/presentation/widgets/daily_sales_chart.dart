import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../data/models/sales_report.dart';

/// Bar chart showing daily sales.
class DailySalesChart extends StatelessWidget {
  const DailySalesChart({super.key, required this.report});

  final SalesReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = report.chartData;
    final maxY = report.maxDailyRevenue.toDouble();

    if (data.isEmpty) {
      return SizedBox(
        height: 140,
        child: Center(
          child: Text(
            'No sales data',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 140,
      child: Column(
        children: [
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                minY: 0,
                barGroups: data.asMap().entries.map((entry) {
                  final index = entry.key;
                  final daily = entry.value;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: daily.amount.toDouble(),
                        width: 12,
                        color: theme.colorScheme.primary,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: theme.colorScheme.primaryContainer,
                        ),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= data.length) {
                          return const SizedBox.shrink();
                        }
                        final date = data[index].date;
                        final isFirst = index == 0;
                        final isLast = index == data.length - 1;
                        final isMid = index == data.length ~/ 2;

                        String label;
                        if (isFirst) {
                          label = 'Start';
                        } else if (isLast) {
                          label = 'Today';
                        } else if (isMid) {
                          label = '${date.day}/${date.month}';
                        } else {
                          return const SizedBox.shrink();
                        }

                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 4,
                          child: Text(
                            label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) =>
                        theme.colorScheme.surfaceContainerHighest,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final daily = data[group.x];
                      return BarTooltipItem(
                        '₱${(daily.amount / 100).toStringAsFixed(2)}',
                        theme.textTheme.bodySmall!.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
