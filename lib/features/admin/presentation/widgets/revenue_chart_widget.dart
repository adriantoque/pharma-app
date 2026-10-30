import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../../../reports/presentation/providers/reports_provider.dart';

/// A smooth line chart showing revenue growth over time.
/// Uses the ReportsProvider's sales report data.
class RevenueGrowthChart extends StatelessWidget {
  const RevenueGrowthChart({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<ReportsProvider>();
    final salesReport = reports.salesReport;

    // If no data has loaded yet, show placeholder
    if (salesReport == null || !reports.hasLoadedOnce) {
      return _buildLoadingPlaceholder(context);
    }

    final chartData = salesReport.chartData;
    final maxRevenue = salesReport.maxDailyRevenue;

    // If no chart data, show empty state
    if (chartData.isEmpty) {
      return _buildEmptyState(context);
    }

    // Prepare data points for the chart
    // Convert DailySales to FlSpot points
    final spots = chartData.asMap().entries.map((entry) {
      final index = entry.key;
      final dailySale = entry.value;
      // Calculate a y value based on the daily amount
      final yValue = maxRevenue > 0
          ? (dailySale.amount / maxRevenue) * 10.0
          : 0.0;
      return FlSpot(index.toDouble(), yValue);
    }).toList();

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue Growth',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withValues(alpha: 0.15),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        // The y axis is the daily amount scaled to 0-10, so
                        // undo the scale before formatting: without this the
                        // label is the raw centavo figure with a "k" bolted
                        // on, which reads as a number nobody can trust.
                        final centavos = (value / 10) * maxRevenue;
                        final pesos = centavos / 100;
                        return Text(
                          '₱${_shortAmount(pesos)}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        // Label every other point: seven dates do not fit
                        // under a phone-width chart without overlapping.
                        if (index < 0 ||
                            index >= chartData.length ||
                            index.isOdd) {
                          return const Text('');
                        }
                        final date = chartData[index].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            '${date.day}/${date.month}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: Theme.of(context).colorScheme.primary,
                    barWidth: 3.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Summary info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                salesReport.formattedTotalRevenue,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${salesReport.totalOrders} orders',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A peso figure short enough for a 30px axis gutter: `₱950`, `₱1.2k`.
  static String _shortAmount(double pesos) {
    if (pesos >= 1000) {
      return '${(pesos / 1000).toStringAsFixed(1)}k';
    }
    return pesos.toStringAsFixed(0);
  }

  Widget _buildLoadingPlaceholder(BuildContext ctx) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(ctx).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext ctx) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(ctx).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text(
          'No sales data for this period',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}